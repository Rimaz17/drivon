package com.drivon.api.assistant;

import com.drivon.api.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/assistant")
@Tag(
    name = "Ask My Vehicle",
    description = "Questions about your vehicles, answered from your data")
class AssistantController {

  private final AssistantService assistant;

  AssistantController(AssistantService assistant) {
    this.assistant = assistant;
  }

  @PostMapping("/chat")
  @Operation(
      summary = "Ask a question",
      description =
          "The assistant looks up the user's own data with read-only tools and answers in plain"
              + " text. Send the latest turns as `history` for follow-up questions (the server"
              + " keeps none) and the selected vehicle as `vehicleId`. Limited per user.")
  @ApiResponse(responseCode = "200", description = "The answer")
  @ApiResponse(responseCode = "400", description = "VALIDATION_FAILED")
  @ApiResponse(
      responseCode = "422",
      description = "ASSISTANT_INCOMPLETE (couldn't finish; ask more simply)")
  @ApiResponse(responseCode = "429", description = "RATE_LIMITED, with Retry-After")
  @ApiResponse(
      responseCode = "503",
      description = "ASSISTANT_UNAVAILABLE (not set up, providers failing or too slow)")
  ChatResponse chat(@CurrentUserId UUID userId, @Valid @RequestBody ChatRequest request) {
    return assistant.chat(userId, request);
  }
}
