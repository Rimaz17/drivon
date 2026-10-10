package com.drivon.api.assistant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.common.error.RateLimitedException;
import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.time.Duration;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

@WebMvcTest(AssistantController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class AssistantControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final String PATH = "/api/v1/assistant/chat";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private AssistantService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  private MvcTestResult post(String body) {
    return mvc.post()
        .uri(PATH)
        .with(jwt().jwt(token -> token.subject(USER.toString())))
        .contentType(MediaType.APPLICATION_JSON)
        .content(body)
        .exchange();
  }

  @Test
  void answersTheSignedInUser() {
    when(service.chat(eq(USER), any())).thenReturn(new ChatResponse("Rs. 18,500."));

    assertThat(post("{\"message\": \"Fuel in September?\"}"))
        .hasStatusOk()
        .bodyJson()
        .isLenientlyEqualTo("{\"reply\": \"Rs. 18,500.\"}");
  }

  @Test
  void rejectsLongQuestionsAndLongHistories() {
    assertThat(post("{\"message\": \"" + "a".repeat(1001) + "\"}"))
        .hasStatus(HttpStatus.BAD_REQUEST);
    String history =
        IntStream.range(0, ChatRequest.MAX_HISTORY + 1)
            .mapToObj(i -> "{\"role\": \"USER\", \"text\": \"q\"}")
            .collect(Collectors.joining(","));
    assertThat(post("{\"message\": \"Hi\", \"history\": [" + history + "]}"))
        .hasStatus(HttpStatus.BAD_REQUEST);
    assertThat(
            post("{\"message\": \"Hi\", \"history\": [{\"role\": \"SYSTEM\", \"text\": \"x\"}]}"))
        .hasStatus(HttpStatus.BAD_REQUEST);
    verifyNoInteractions(service);
  }

  @Test
  void outagesAndLimitsHaveTheirCodes() {
    when(service.chat(eq(USER), any()))
        .thenThrow(new DrivonException(ErrorCode.ASSISTANT_UNAVAILABLE, "Try again in a minute."))
        .thenThrow(new DrivonException(ErrorCode.ASSISTANT_INCOMPLETE, "Ask more simply."))
        .thenThrow(new RateLimitedException(Duration.ofMinutes(30)));

    assertThat(post("{\"message\": \"Hi\"}"))
        .hasStatus(HttpStatus.SERVICE_UNAVAILABLE)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ASSISTANT_UNAVAILABLE");
    assertThat(post("{\"message\": \"Hi\"}"))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ASSISTANT_INCOMPLETE");
    assertThat(post("{\"message\": \"Hi\"}"))
        .hasStatus(HttpStatus.TOO_MANY_REQUESTS)
        .hasHeader(HttpHeaders.RETRY_AFTER, "1800");
  }
}
