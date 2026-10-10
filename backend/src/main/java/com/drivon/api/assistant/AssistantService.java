package com.drivon.api.assistant;

import com.drivon.api.assistant.llm.LlmException;
import com.drivon.api.assistant.llm.LlmMessage;
import com.drivon.api.assistant.llm.LlmRequest;
import com.drivon.api.assistant.llm.LlmRouter;
import com.drivon.api.assistant.llm.ToolCall;
import com.drivon.api.assistant.llm.ToolSpec;
import com.drivon.api.assistant.tools.AssistantTools;
import com.drivon.api.assistant.tools.ToolContext;
import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.config.AssistantProperties;
import com.drivon.api.vehicle.VehicleResponse;
import com.drivon.api.vehicle.VehicleService;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Answers questions about the user's vehicles. The model decides which read-only tools to call; the
 * server runs them for the signed-in user only and sends the results back until the model answers
 * in text, with a cap on rounds and time. See docs/adr/0014-ask-my-vehicle.md.
 */
@Service
public class AssistantService {

  /** Tool calls run per round; more are answered with an error so every call gets a result. */
  static final int MAX_CALLS_PER_ROUND = 8;

  private static final Logger log = LoggerFactory.getLogger(AssistantService.class);

  private final LlmRouter router;
  private final AssistantTools tools;
  private final VehicleService vehicles;
  private final BusinessCalendar calendar;
  private final AssistantProperties properties;
  private final AssistantRateLimiter rateLimiter;
  private final Clock clock;

  AssistantService(
      LlmRouter router,
      AssistantTools tools,
      VehicleService vehicles,
      BusinessCalendar calendar,
      AssistantProperties properties,
      AssistantRateLimiter rateLimiter,
      Clock clock) {
    this.router = router;
    this.tools = tools;
    this.vehicles = vehicles;
    this.calendar = calendar;
    this.properties = properties;
    this.rateLimiter = rateLimiter;
    this.clock = clock;
  }

  /**
   * Answers one question.
   *
   * @throws DrivonException {@code ASSISTANT_UNAVAILABLE} when no provider is set up, both fail or
   *     time runs out; {@code ASSISTANT_INCOMPLETE} when the model doesn't finish within the tool
   *     round cap; {@code RATE_LIMITED} when the user asked too many questions
   */
  public ChatResponse chat(UUID userId, ChatRequest request) {
    if (!router.available()) {
      throw new DrivonException(
          ErrorCode.ASSISTANT_UNAVAILABLE, "Ask My Vehicle isn't set up on this server.");
    }
    rateLimiter.consume(userId);

    List<VehicleResponse> owned = vehicles.list(userId);
    ToolContext context =
        new ToolContext(userId, ownedOrNull(request.vehicleId(), owned), owned, calendar.today());
    String systemPrompt = AssistantPrompt.system(context);
    List<ToolSpec> specs = tools.specs();
    List<LlmMessage> messages = new ArrayList<>();
    for (ChatRequest.Turn turn :
        request.history() == null ? List.<ChatRequest.Turn>of() : request.history()) {
      messages.add(
          turn.role() == ChatRequest.Role.USER
              ? new LlmMessage.User(turn.text().strip())
              : LlmMessage.Assistant.text(turn.text().strip()));
    }
    messages.add(new LlmMessage.User(request.message().strip()));

    LlmRouter.Conversation conversation = router.conversation();
    Instant deadline = clock.instant().plus(properties.totalTimeout());
    for (int round = 0; ; round++) {
      if (clock.instant().isAfter(deadline)) {
        throw unavailable("took too long");
      }
      LlmMessage.Assistant reply;
      try {
        reply = conversation.complete(new LlmRequest(systemPrompt, messages, specs));
      } catch (LlmException e) {
        throw unavailable(e.getMessage());
      }
      if (reply.toolCalls().isEmpty()) {
        String text = reply.text().strip();
        if (text.isEmpty()) {
          throw incomplete();
        }
        return new ChatResponse(text);
      }
      if (round >= properties.maxToolRounds()) {
        throw incomplete();
      }
      messages.add(reply);
      List<ToolCall> calls = reply.toolCalls();
      for (int i = 0; i < calls.size(); i++) {
        ToolCall call = calls.get(i);
        String result =
            i < MAX_CALLS_PER_ROUND
                ? tools.execute(call, context)
                : "{\"error\": \"Too many lookups at once; ask for fewer.\"}";
        messages.add(new LlmMessage.ToolResult(call.id(), call.name(), result));
      }
    }
  }

  /** The app's selected vehicle, if it really is one of the user's. */
  private static @Nullable UUID ownedOrNull(@Nullable UUID vehicleId, List<VehicleResponse> owned) {
    if (vehicleId == null) {
      return null;
    }
    return owned.stream().anyMatch(vehicle -> vehicle.id().equals(vehicleId)) ? vehicleId : null;
  }

  private static DrivonException unavailable(@Nullable String reason) {
    log.warn("Ask My Vehicle couldn't answer: {}", reason);
    return new DrivonException(
        ErrorCode.ASSISTANT_UNAVAILABLE,
        "Ask My Vehicle can't answer right now. Please try again in a minute.");
  }

  private static DrivonException incomplete() {
    return new DrivonException(
        ErrorCode.ASSISTANT_INCOMPLETE,
        "I couldn't work that out. Try asking in a simpler way, one thing at a time.");
  }
}
