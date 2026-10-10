package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.ReminderJobProperties;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import com.drivon.api.reminder.ReminderNotifier.RunSummary;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(ReminderJobController.class)
@Import({
  SecurityConfig.class,
  WebConfig.class,
  JacksonConfig.class,
  ReminderJobControllerTest.Secret.class
})
class ReminderJobControllerTest {

  static final String SECRET = "a-long-enough-shared-secret-for-the-job";

  @TestConfiguration
  static class Secret {
    @Bean
    ReminderJobProperties reminderJobProperties() {
      return new ReminderJobProperties(SECRET);
    }
  }

  @Autowired private MockMvcTester mvc;
  @MockitoBean private ReminderNotifier notifier;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void runsWithTheSecretAndNoUserToken() {
    when(notifier.notifyAllDue()).thenReturn(new RunSummary(4, 2, 1));

    assertThat(
            mvc.post()
                .uri(ReminderJobController.PATH)
                .header(ReminderJobController.SECRET_HEADER, SECRET))
        .hasStatusOk()
        .bodyJson()
        .isLenientlyEqualTo("{\"checked\": 4, \"notified\": 2, \"failed\": 1}");
  }

  @Test
  void aWrongOrMissingSecretIsRejected() {
    assertThat(
            mvc.post()
                .uri(ReminderJobController.PATH)
                .header(ReminderJobController.SECRET_HEADER, SECRET + "x"))
        .hasStatus(HttpStatus.UNAUTHORIZED)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("UNAUTHENTICATED");
    assertThat(mvc.post().uri(ReminderJobController.PATH)).hasStatus(HttpStatus.UNAUTHORIZED);
    verifyNoInteractions(notifier);
  }

  @Test
  void onlyPostIsOpen() {
    assertThat(mvc.get().uri(ReminderJobController.PATH)).hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void aShortSecretIsRefusedAtStartup() {
    assertThatThrownBy(() -> new ReminderJobProperties("too-short"))
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("REMINDERS_JOB_SECRET");
    assertThat(new ReminderJobProperties("  ").enabled()).isFalse();
  }
}
