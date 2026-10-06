package com.drivon.api;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.web.RequestIdFilter;
import com.drivon.api.support.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@IntegrationTest
class ApiBaselineIntegrationTest {

  @Autowired private MockMvcTester mvc;

  @Test
  void healthEndpointIsPublicAndReportsUp() {
    assertThat(mvc.get().uri("/actuator/health"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.status")
        .isEqualTo("UP");
  }

  @Test
  void openApiDocsArePublic() {
    assertThat(mvc.get().uri("/v3/api-docs"))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.info.title")
        .isEqualTo("Drivon API");
  }

  @Test
  void apiEndpointsRequireAuthentication() {
    assertThat(mvc.get().uri("/api/v1/vehicles")).hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void nonPublicActuatorEndpointsAreNotExposed() {
    assertThat(mvc.get().uri("/actuator/env")).hasStatus(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void everyResponseCarriesARequestId() {
    assertThat(mvc.get().uri("/actuator/health")).headers().containsHeader(RequestIdFilter.HEADER);
  }
}
