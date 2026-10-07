package com.drivon.api.support;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import java.io.UnsupportedEncodingException;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** Small helpers for integration tests that drive the API like a client would. */
public final class ApiClient {

  private final MockMvcTester mvc;

  public ApiClient(MockMvcTester mvc) {
    this.mvc = mvc;
  }

  /** A freshly registered user with its tokens. */
  public record Session(String userId, String email, String accessToken, String refreshToken) {
    public String bearer() {
      return "Bearer " + accessToken;
    }
  }

  public static String uniqueEmail() {
    return "user-" + UUID.randomUUID() + "@example.com";
  }

  public Session register() {
    return register(uniqueEmail(), "correct-horse-battery");
  }

  public Session register(String email, String password) {
    MvcTestResult result =
        mvc.post()
            .uri("/api/v1/auth/register")
            .contentType(MediaType.APPLICATION_JSON)
            .content(
                """
                {"name": "Test Driver", "email": "%s", "password": "%s"}
                """
                    .formatted(email, password))
            .exchange();
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return session(result, email);
  }

  public static Session session(MvcTestResult result, String email) {
    String body = body(result);
    return new Session(
        JsonPath.read(body, "$.user.id"),
        email,
        JsonPath.read(body, "$.accessToken"),
        JsonPath.read(body, "$.refreshToken"));
  }

  public MvcTestResult postJson(String uri, String json, String bearer) {
    var request = mvc.post().uri(uri).contentType(MediaType.APPLICATION_JSON).content(json);
    if (bearer != null) {
      request = request.header(HttpHeaders.AUTHORIZATION, bearer);
    }
    return request.exchange();
  }

  public static String body(MvcTestResult result) {
    try {
      return result.getResponse().getContentAsString();
    } catch (UnsupportedEncodingException e) {
      throw new IllegalStateException(e);
    }
  }
}
