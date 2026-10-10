package com.drivon.api.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.drivon.api.config.JacksonConfig;
import com.drivon.api.config.SecurityConfig;
import com.drivon.api.config.WebConfig;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(DeviceTokenController.class)
@Import({SecurityConfig.class, WebConfig.class, JacksonConfig.class})
class DeviceTokenControllerTest {

  private static final UUID USER = UUID.randomUUID();
  private static final String TOKEN = "dGVzdA:APA91bH-x_y1";

  @Autowired private MockMvcTester mvc;
  @MockitoBean private DeviceTokenService service;
  @MockitoBean private JwtDecoder jwtDecoder;

  @Test
  void registersTheSignedInUsersDevice() {
    assertThat(
            mvc.put()
                .uri("/api/v1/device-tokens")
                .with(jwt().jwt(t -> t.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"token": "%s", "platform": "ANDROID"}
                    """
                        .formatted(TOKEN)))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).register(USER, new DeviceTokenRequest(TOKEN, DevicePlatform.ANDROID));
  }

  @Test
  void rejectsSomethingThatIsNotAToken() {
    assertThat(
            mvc.put()
                .uri("/api/v1/device-tokens")
                .with(jwt().jwt(t -> t.subject(USER.toString())))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\": \"<script>\", \"platform\": \"ANDROID\"}"))
        .hasStatus(HttpStatus.BAD_REQUEST);
    verifyNoInteractions(service);
  }

  @Test
  void unregistersByTokenInThePath() {
    assertThat(
            mvc.delete()
                .uri("/api/v1/device-tokens/" + TOKEN)
                .with(jwt().jwt(t -> t.subject(USER.toString()))))
        .hasStatus(HttpStatus.NO_CONTENT);
    verify(service).unregister(USER, TOKEN);
  }

  @Test
  void needsSigningIn() {
    assertThat(mvc.delete().uri("/api/v1/device-tokens/" + TOKEN))
        .hasStatus(HttpStatus.UNAUTHORIZED);
  }
}
