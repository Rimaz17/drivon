package com.drivon.api.vehicle;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

@IntegrationTest
class VehicleIntegrationTest {

  @Autowired private MockMvcTester mvc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String body(String registration, int odometer) {
    return """
        {"make": "Toyota", "model": "Aqua", "year": 2018, "registrationNumber": "%s",
         "fuelType": "HYBRID", "currentOdometerKm": %d}
        """
        .formatted(registration, odometer);
  }

  private String create(Session session, String registration) {
    MvcTestResult result =
        api.postJson("/api/v1/vehicles", body(registration, 1000), session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  @Test
  void userCanAddListUpdateAndDeleteTheirVehicles() {
    Session session = api.register();
    String id = create(session, "cab - 1234");

    assertThat(
            mvc.get().uri("/api/v1/vehicles").header(HttpHeaders.AUTHORIZATION, session.bearer()))
        .hasStatusOk()
        .bodyJson()
        .satisfies(
            json -> {
              json.assertThat().extractingPath("$.length()").isEqualTo(1);
              json.assertThat().extractingPath("$[0].registrationNumber").isEqualTo("CAB-1234");
            });

    assertThat(
            mvc.put()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, session.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body("CAB-1234", 1500)))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.currentOdometerKm")
        .isEqualTo(1500);

    assertThat(
            mvc.delete()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(
            mvc.get()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, session.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
  }

  @Test
  void aThirdVehicleIsRefused() {
    Session session = api.register();
    create(session, "CAB-0001");
    create(session, "CAB-0002");

    assertThat(api.postJson("/api/v1/vehicles", body("CAB-0003", 0), session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VEHICLE_LIMIT_REACHED");
  }

  @Test
  void theSamePlateTwiceForOneUserIsAConflictButTwoUsersMayShareIt() {
    Session owner = api.register();
    Session other = api.register();
    create(owner, "CAB-1234");

    assertThat(api.postJson("/api/v1/vehicles", body("cab-1234", 0), owner.bearer()))
        .hasStatus(HttpStatus.CONFLICT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("REGISTRATION_NUMBER_IN_USE");
    assertThat(api.postJson("/api/v1/vehicles", body("CAB-1234", 0), other.bearer()))
        .hasStatus(HttpStatus.CREATED);
  }

  @Test
  void odometerCannotGoBackwards() {
    Session session = api.register();
    String id = create(session, "CAB-1234");

    assertThat(
            mvc.put()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, session.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body("CAB-1234", 999)))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("ODOMETER_DECREASE");
  }

  @Test
  void usersCanNeverSeeOrChangeAnotherUsersVehicle() {
    Session owner = api.register();
    Session intruder = api.register();
    String id = create(owner, "CAB-1234");

    assertThat(
            mvc.get()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("VEHICLE_NOT_FOUND");
    assertThat(
            mvc.put()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, intruder.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(body("HACK-1", 2000)))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(
            mvc.delete()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, intruder.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(
            mvc.get().uri("/api/v1/vehicles").header(HttpHeaders.AUTHORIZATION, intruder.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.length()")
        .isEqualTo(0);

    // The owner's vehicle is untouched.
    assertThat(
            mvc.get()
                .uri("/api/v1/vehicles/{id}", id)
                .header(HttpHeaders.AUTHORIZATION, owner.bearer()))
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.registrationNumber")
        .isEqualTo("CAB-1234");
  }
}
