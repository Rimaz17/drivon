package com.drivon.api.document;

import static org.assertj.core.api.Assertions.assertThat;

import com.drivon.api.common.storage.ObjectStorage;
import com.drivon.api.common.time.BusinessCalendar;
import com.drivon.api.support.ApiClient;
import com.drivon.api.support.ApiClient.Session;
import com.drivon.api.support.IntegrationTest;
import com.jayway.jsonpath.JsonPath;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.test.web.servlet.assertj.MvcTestResult;

/** The whole upload flow against Postgres and S3Mock, as the app performs it. */
@IntegrationTest
class DocumentIntegrationTest {

  private static final LocalDate TODAY = LocalDate.now(BusinessCalendar.ZONE);
  private static final HttpClient HTTP = HttpClient.newHttpClient();

  @Autowired private MockMvcTester mvc;
  @Autowired private ObjectStorage storage;
  private ApiClient api;

  @BeforeEach
  void setUp() {
    api = new ApiClient(mvc);
  }

  private static String documents(String vehicleId) {
    return "/api/v1/vehicles/" + vehicleId + "/documents";
  }

  private static String uploadBody(String id, String type, LocalDate expiry, int size) {
    return """
        {"id": "%s", "type": "%s", "issueDate": "%s", "expiryDate": %s,
         "notes": "Policy 123", "contentType": "application/pdf", "sizeBytes": %d}
        """
        .formatted(
            id, type, TODAY.minusYears(1), expiry == null ? "null" : "\"" + expiry + "\"", size);
  }

  /** Starts an upload and returns the response body. */
  private String start(Session session, String vehicleId, String body) {
    MvcTestResult result = api.postJson(documents(vehicleId), body, session.bearer());
    assertThat(result).hasStatus(HttpStatus.CREATED);
    return ApiClient.body(result);
  }

  /** Sends the file to the presigned URL, as the app does, without the API's token. */
  private static int put(String uploadResponse, byte[] file)
      throws IOException, InterruptedException {
    Map<String, String> headers = JsonPath.read(uploadResponse, "$.upload.headers");
    HttpRequest.Builder request =
        HttpRequest.newBuilder(URI.create(JsonPath.read(uploadResponse, "$.upload.url")))
            .PUT(HttpRequest.BodyPublishers.ofByteArray(file));
    // Java's client sets Content-Length from the body itself.
    headers.forEach(
        (name, value) -> {
          if (!name.equalsIgnoreCase("content-length")) {
            request.header(name, value);
          }
        });
    return HTTP.send(request.build(), HttpResponse.BodyHandlers.discarding()).statusCode();
  }

  private static byte[] pdf(int size) {
    byte[] file = new byte[size];
    byte[] header = "%PDF-1.7\n".getBytes(StandardCharsets.US_ASCII);
    System.arraycopy(header, 0, file, 0, header.length);
    return file;
  }

  private String upload(Session session, String vehicleId, String type, LocalDate expiry)
      throws IOException, InterruptedException {
    String id = UUID.randomUUID().toString();
    String started = start(session, vehicleId, uploadBody(id, type, expiry, 64));
    assertThat(put(started, pdf(64))).isEqualTo(200);
    assertThat(api.postJson(documents(vehicleId) + "/" + id + "/confirm", "", session.bearer()))
        .hasStatusOk();
    return id;
  }

  private static String keyOf(Session session, String vehicleId, String documentId) {
    return "users/"
        + session.userId()
        + "/vehicles/"
        + vehicleId
        + "/documents/"
        + documentId
        + ".pdf";
  }

  @Test
  void uploadsConfirmsListsAndDownloadsADocument() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-1234", 46_000);
    String id = UUID.randomUUID().toString();
    byte[] file = pdf(2_048);

    String started =
        start(session, vehicleId, uploadBody(id, "INSURANCE", TODAY.plusMonths(6), file.length));
    assertThat(JsonPath.<String>read(started, "$.document.status")).isEqualTo("PENDING");
    // Not listed until confirmed.
    assertThat(
            JsonPath.<Integer>read(
                ApiClient.body(api.get(documents(vehicleId), session.bearer())), "$.totalElements"))
        .isZero();

    assertThat(put(started, file)).isEqualTo(200);
    MvcTestResult confirmed =
        api.postJson(documents(vehicleId) + "/" + id + "/confirm", "", session.bearer());
    assertThat(confirmed).hasStatusOk().bodyJson().extractingPath("$.status").isEqualTo("ACTIVE");

    MvcTestResult list = api.get(documents(vehicleId), session.bearer());
    assertThat(list).hasStatusOk();
    assertThat(JsonPath.<List<String>>read(ApiClient.body(list), "$.content[*].id"))
        .containsExactly(id);

    MvcTestResult link =
        api.get(documents(vehicleId) + "/" + id + "/download-url", session.bearer());
    assertThat(link).hasStatusOk();
    HttpResponse<byte[]> download =
        HTTP.send(
            HttpRequest.newBuilder(URI.create(JsonPath.read(ApiClient.body(link), "$.url")))
                .build(),
            HttpResponse.BodyHandlers.ofByteArray());
    assertThat(download.statusCode()).isEqualTo(200);
    assertThat(download.body()).isEqualTo(file);
  }

  @Test
  void retryingAStartedUploadResumesIt() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-2001", 46_000);
    String id = UUID.randomUUID().toString();
    String body = uploadBody(id, "RECEIPT", null, 64);
    start(session, vehicleId, body);

    MvcTestResult retry = api.postJson(documents(vehicleId), body, session.bearer());

    assertThat(retry).hasStatusOk();
    assertThat(put(ApiClient.body(retry), pdf(64))).isEqualTo(200);
    assertThat(api.postJson(documents(vehicleId) + "/" + id + "/confirm", "", session.bearer()))
        .hasStatusOk();
    MvcTestResult afterConfirm = api.postJson(documents(vehicleId), body, session.bearer());
    assertThat(afterConfirm).hasStatusOk().bodyJson().extractingPath("$.upload").isNull();
  }

  @Test
  void confirmingWithoutAMatchingFileFails() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-2002", 46_000);
    String id = UUID.randomUUID().toString();
    String started = start(session, vehicleId, uploadBody(id, "INVOICE", null, 64));
    String confirm = documents(vehicleId) + "/" + id + "/confirm";

    assertThat(api.postJson(confirm, "", session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("UPLOAD_NOT_FOUND");

    // S3Mock doesn't enforce the signed length the way R2 does, so the API's own check catches it.
    assertThat(put(started, pdf(65))).isEqualTo(200);
    assertThat(api.postJson(confirm, "", session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("UPLOAD_MISMATCH");
    assertThat(storage.head(keyOf(session, vehicleId, id))).isEmpty();
  }

  @Test
  void editingAndDeletingADocumentAlsoRemovesItsFile() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-2003", 46_000);
    String id = upload(session, vehicleId, "REVENUE_LICENCE", TODAY.plusMonths(3));
    String path = documents(vehicleId) + "/" + id;

    assertThat(
            api.putJson(
                path,
                """
                {"type": "REVENUE_LICENCE", "issueDate": "%s", "expiryDate": "%s"}
                """
                    .formatted(TODAY, TODAY),
                session.bearer()))
        .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
        .bodyJson()
        .extractingPath("$.code")
        .isEqualTo("DOCUMENT_DATES_INVALID");
    assertThat(storage.head(keyOf(session, vehicleId, id))).isPresent();

    assertThat(api.delete(path, session.bearer())).hasStatus(HttpStatus.NO_CONTENT);

    assertThat(api.get(path, session.bearer())).hasStatus(HttpStatus.NOT_FOUND);
    assertThat(storage.head(keyOf(session, vehicleId, id))).isEmpty();
  }

  @Test
  void deletingAVehicleDeletesItsDocumentFiles() throws Exception {
    Session session = api.register();
    String vehicleId = api.createVehicle(session, "CAB-2004", 46_000);
    String id = upload(session, vehicleId, "REGISTRATION", null);

    assertThat(api.delete("/api/v1/vehicles/" + vehicleId, session.bearer()))
        .hasStatus(HttpStatus.NO_CONTENT);

    assertThat(storage.head(keyOf(session, vehicleId, id))).isEmpty();
  }

  @Test
  void listsDocumentsExpiringSoonAcrossTheUsersVehicles() throws Exception {
    Session session = api.register();
    String car = api.createVehicle(session, "CAB-2005", 46_000);
    String bike = api.createVehicle(session, "BCD-2006", 12_000);
    String expired = upload(session, bike, "INSURANCE", TODAY.minusDays(3));
    String soon = upload(session, car, "REVENUE_LICENCE", TODAY.plusDays(10));
    upload(session, car, "INSURANCE", TODAY.plusDays(200));
    upload(session, car, "RECEIPT", null);
    start(
        session, car, uploadBody(UUID.randomUUID().toString(), "INSURANCE", TODAY.plusDays(1), 64));
    Session other = api.register();
    upload(other, api.createVehicle(other, "CAB-2005", 46_000), "INSURANCE", TODAY);

    MvcTestResult result = api.get("/api/v1/documents/expiring?withinDays=30", session.bearer());

    assertThat(result).hasStatusOk();
    assertThat(JsonPath.<List<String>>read(ApiClient.body(result), "$[*].id"))
        .containsExactly(expired, soon);
  }

  @Test
  void anotherUsersDocumentsStayHidden() throws Exception {
    Session owner = api.register();
    String vehicleId = api.createVehicle(owner, "CAB-2007", 46_000);
    String id = upload(owner, vehicleId, "INSURANCE", TODAY.plusMonths(6));
    Session intruder = api.register();
    String path = documents(vehicleId) + "/" + id;

    for (MvcTestResult result :
        List.of(
            api.get(path, intruder.bearer()),
            api.get(path + "/download-url", intruder.bearer()),
            api.postJson(path + "/confirm", "", intruder.bearer()),
            api.putJson(path, "{\"type\": \"OTHER\"}", intruder.bearer()),
            api.delete(path, intruder.bearer()),
            api.postJson(
                documents(vehicleId),
                uploadBody(UUID.randomUUID().toString(), "OTHER", null, 64),
                intruder.bearer()))) {
      assertThat(result)
          .hasStatus(HttpStatus.NOT_FOUND)
          .bodyJson()
          .extractingPath("$.code")
          .isEqualTo("VEHICLE_NOT_FOUND");
    }
    assertThat(storage.head(keyOf(owner, vehicleId, id))).isPresent();
  }
}
