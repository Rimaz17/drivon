package com.drivon.api.reminder;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.notification.PushMessage;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.drivon.api.support.RecordingPushSender;
import com.jayway.jsonpath.JsonPath;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** Reminders from services, documents and the user, and their notifications, end to end. */
@IntegrationTest
class ReminderIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);
  private static final String JOB_SECRET = "test-only-reminders-job-secret-0123456789";
  private static final HttpClient HTTP = HttpClient.newHttpClient();

  @Autowired private MockMvcTester mvc;
  @Autowired private RecordingPushSender pushes;
  @Autowired private JdbcTemplate jdbc;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String reminders(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/reminders";
  }

  private List<Map<String, Object>> list(Session session, String vehicleId) {
    MvcTestResult result = api.get(reminders(vehicleId), session.bearer());
    assertThat(result).hasStatusOk();
    return JsonPath.read(ApiClient.body(result), "$");
  }

  private String logService(
      Session session,
      String vehicleId,
      String type,
      int odometer,
      LocalDate next,
      Integer nextKm) {
    MvcTestResult result =
        api.postJson(
            "/api/v1/vehicles/" + vehicleId + "/maintenance-records",
            """
            {"serviceType": "%s", "date": "%s", "odometerKm": %d, "cost": "9800",
             "nextServiceDate": %s, "nextServiceKm": %s}
            """
                .formatted(
                    type, TODAY, odometer, next == null ? "null" : "\"" + next + "\"", nextKm),
            session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  private String addReminder(Session session, String vehicleId, LocalDate due, Integer dueKm) {
    MvcTestResult result =
        api.postJson(
            reminders(vehicleId),
            """
            {"title": "Emission test", "dueDate": %s, "dueKm": %s}
            """
                .formatted(due == null ? "null" : "\"" + due + "\"", dueKm),
            session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return JsonPath.read(ApiClient.body(result), "$.id");
  }

  private void registerDevice(Session session, String token) {
    assertThat(
            mvc.put()
                .uri("/api/v1/device-tokens")
                .header("Authorization", session.bearer())
                .contentType("application/json")
                .content(
                    """
                    {"token": "%s", "platform": "ANDROID"}
                    """
                        .formatted(token)))
        .hasStatus(HttpStatus.NO_CONTENT);
  }

  private MvcTestResult runJob(String secret) {
    var request = mvc.post().uri("/internal/reminders/run");
    if (secret != null) {
      request = request.header("X-Drivon-Job-Secret", secret);
    }
    return request.exchange();
  }

  private static String token() {
    return "token-" + UUID.randomUUID();
  }

  @Test
  void serviceRemindersFollowTheLatestRecordOfEachType() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);

    String first = logService(session, vehicleId, "OIL_CHANGE", 45_000, null, 50_000);
    List<Map<String, Object>> afterFirst = list(session, vehicleId);
    assertThat(afterFirst).hasSize(1);
    assertThat(afterFirst.get(0))
        .containsEntry("source", "SERVICE")
        .containsEntry("serviceType", "OIL_CHANGE")
        .containsEntry("sourceId", first)
        .containsEntry("dueKm", 50_000)
        .containsEntry("kmRemaining", 5_000)
        .containsEntry("status", "UPCOMING");

    String second = logService(session, vehicleId, "OIL_CHANGE", 46_000, TODAY.plusDays(3), 51_000);
    assertThat(list(session, vehicleId))
        .singleElement()
        .satisfies(
            r ->
                assertThat(r)
                    .containsEntry("sourceId", second)
                    .containsEntry("dueDate", TODAY.plusDays(3).toString())
                    .containsEntry("status", "DUE_SOON"));

    // Deleting the newest record makes the older one the latest again.
    assertThat(
            api.delete(
                "/api/v1/vehicles/" + vehicleId + "/maintenance-records/" + second,
                session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(list(session, vehicleId))
        .singleElement()
        .satisfies(r -> assertThat(r).containsEntry("sourceId", first));

    assertThat(
            api.delete(
                "/api/v1/vehicles/" + vehicleId + "/maintenance-records/" + first,
                session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(list(session, vehicleId)).isEmpty();
  }

  @Test
  void documentRemindersFollowTheLatestExpiryOfEachType() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);

    String old = uploadDocument(session, vehicleId, "INSURANCE", TODAY.plusDays(10));
    assertThat(list(session, vehicleId))
        .singleElement()
        .satisfies(
            r ->
                assertThat(r)
                    .containsEntry("source", "DOCUMENT")
                    .containsEntry("documentType", "INSURANCE")
                    .containsEntry("sourceId", old)
                    .containsEntry("status", "DUE_SOON")
                    .containsEntry("remindFrom", TODAY.minusDays(20).toString()));

    String renewed = uploadDocument(session, vehicleId, "INSURANCE", TODAY.plusYears(1));
    assertThat(list(session, vehicleId))
        .singleElement()
        .satisfies(
            r ->
                assertThat(r)
                    .containsEntry("sourceId", renewed)
                    .containsEntry("status", "UPCOMING"));

    assertThat(
            api.delete("/api/v1/vehicles/" + vehicleId + "/documents/" + renewed, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(list(session, vehicleId))
        .singleElement()
        .satisfies(r -> assertThat(r).containsEntry("sourceId", old));
  }

  @Test
  void theUserManagesTheirOwnRemindersOnly() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    String id = addReminder(session, vehicleId, TODAY.plusDays(60), null);

    MvcTestResult updated =
        api.putJson(
            reminders(vehicleId) + "/" + id,
            """
            {"title": "Emission test and licence", "dueDate": "%s", "dueKm": 60000}
            """
                .formatted(TODAY.plusDays(60)),
            session.bearer());
    assertThat(updated)
        .hasStatusOk()
        .bodyJson()
        .extractingPath("$.title")
        .isEqualTo("Emission test and licence");

    String serviceRecord = logService(session, vehicleId, "TYRE_ROTATION", 45_000, null, 55_000);
    String serviceReminder =
        list(session, vehicleId).stream()
            .filter(r -> serviceRecord.equals(r.get("sourceId")))
            .map(r -> (String) r.get("id"))
            .findFirst()
            .orElseThrow();
    assertThat(api.delete(reminders(vehicleId) + "/" + serviceReminder, session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("REMINDER_READ_ONLY");

    assertThat(api.delete(reminders(vehicleId) + "/" + id, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(list(session, vehicleId)).hasSize(1);
  }

  @Test
  void anotherUserCantSeeOrChangeReminders() {
    Session owner = api.register();
    Session stranger = api.register();
    String vehicleId = api.createVehicle(owner, "CAB-1234", 45_000);
    String id = addReminder(owner, vehicleId, TODAY.plusDays(5), null);
    api.createVehicle(stranger, "WP-9999", 10_000);

    assertThat(api.get(reminders(vehicleId), stranger.bearer())).hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.get(reminders(vehicleId) + "/" + id, stranger.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    assertThat(api.delete(reminders(vehicleId) + "/" + id, stranger.bearer()))
        .hasStatus(HttpStatus.NOT_FOUND);
    MvcTestResult strangersOwn = api.get("/api/v1/reminders", stranger.bearer());
    assertThat(strangersOwn).hasStatusOk();
    assertThat(JsonPath.<List<String>>read(ApiClient.body(strangersOwn), "$[*].id"))
        .doesNotContain(id);
    assertThat(
            JsonPath.<List<String>>read(
                ApiClient.body(api.get("/api/v1/reminders", owner.bearer())), "$[*].id"))
        .containsExactly(id);
  }

  @Test
  void theDailyRunNeedsTheSecret() {
    assertThat(runJob(null)).hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(runJob("wrong-secret")).hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(runJob(JOB_SECRET)).hasStatusOk().bodyJson().extractingPath("$.checked").isNotNull();
  }

  @Test
  void theDailyRunPushesEachStageOnce() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    String device = token();
    registerDevice(session, device);
    String id = addReminder(session, vehicleId, TODAY, null);

    assertThat(runJob(JOB_SECRET)).hasStatusOk();
    assertThat(runJob(JOB_SECRET)).hasStatusOk();

    List<PushMessage> sent = pushes.sentTo(device);
    assertThat(sent).hasSize(1);
    assertThat(sent.get(0).title()).isEqualTo("Emission test is due");
    assertThat(sent.get(0).data())
        .containsEntry("vehicleId", vehicleId)
        .containsEntry("reminderId", id);
    assertThat(
            jdbc.queryForObject(
                "select notified_stage from reminders where id = ?::uuid", String.class, id))
        .isEqualTo("DUE");
  }

  @Test
  void anOdometerReadingPushesMileageRemindersRightAway() {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 45_000);
    String device = token();
    registerDevice(session, device);
    addReminder(session, vehicleId, null, 46_000);
    String readings = "/api/v1/vehicles/" + vehicleId + "/odometer-readings";

    assertThat(
            api.postJson(
                readings,
                "{\"readingKm\": 45600, \"date\": \"%s\"}".formatted(TODAY),
                session.bearer()))
        .hasStatus(HttpStatus.CREATED);
    assertThat(pushes.sentTo(device))
        .extracting(PushMessage::title)
        .containsExactly("Emission test is due soon");

    assertThat(
            api.postJson(
                readings,
                "{\"readingKm\": 46100, \"date\": \"%s\"}".formatted(TODAY),
                session.bearer()))
        .hasStatus(HttpStatus.CREATED);
    assertThat(pushes.sentTo(device))
        .extracting(PushMessage::title)
        .containsExactly("Emission test is due soon", "Emission test is overdue");
  }

  @Test
  void devicesThatAreGoneAreForgottenAndTokensMoveBetweenAccounts() {
    Session first = api.register();
    Session second = api.register();
    String vehicleId = api.createVehicle(first, "CAB-1234", 45_000);
    String gone = "gone-" + UUID.randomUUID();
    registerDevice(first, gone);
    addReminder(first, vehicleId, TODAY, null);

    assertThat(runJob(JOB_SECRET)).hasStatusOk();
    assertThat(
            jdbc.queryForObject(
                "select count(*) from device_tokens where token = ?", Integer.class, gone))
        .isZero();

    String shared = token();
    registerDevice(first, shared);
    registerDevice(second, shared);
    assertThat(
            jdbc.queryForObject(
                "select user_id::text from device_tokens where token = ?", String.class, shared))
        .isEqualTo(second.userId());

    // Only the owner can unregister it.
    assertThat(api.delete("/api/v1/device-tokens/" + shared, first.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(
            jdbc.queryForObject(
                "select count(*) from device_tokens where token = ?", Integer.class, shared))
        .isOne();
    assertThat(api.delete("/api/v1/device-tokens/" + shared, second.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);
    assertThat(
            jdbc.queryForObject(
                "select count(*) from device_tokens where token = ?", Integer.class, shared))
        .isZero();
  }

  /** Uploads a small PDF through the presigned URL, as the app does, and confirms it. */
  private String uploadDocument(Session session, String vehicleId, String type, LocalDate expiry)
      throws IOException, InterruptedException {
    String id = UUID.randomUUID().toString();
    String documents = "/api/v1/vehicles/" + vehicleId + "/documents";
    MvcTestResult started =
        api.postJson(
            documents,
            """
            {"id": "%s", "type": "%s", "issueDate": "%s", "expiryDate": "%s",
             "contentType": "application/pdf", "sizeBytes": 16}
            """
                .formatted(id, type, TODAY.minusYears(1), expiry),
            session.bearer());
    assertThat(started).hasStatus(HttpStatus.CREATED);
    String body = ApiClient.body(started);
    Map<String, String> headers = JsonPath.read(body, "$.upload.headers");
    HttpRequest.Builder put =
        HttpRequest.newBuilder(URI.create(JsonPath.read(body, "$.upload.url")))
            .PUT(HttpRequest.BodyPublishers.ofByteArray("%PDF-1.7\n.......".getBytes()));
    headers.forEach(
        (name, value) -> {
          if (!name.equalsIgnoreCase("content-length")) {
            put.header(name, value);
          }
        });
    assertThat(HTTP.send(put.build(), HttpResponse.BodyHandlers.discarding()).statusCode())
        .isEqualTo(200);
    assertThat(api.postJson(documents + "/" + id + "/confirm", "", session.bearer())).hasStatusOk();
    return id;
  }
}
