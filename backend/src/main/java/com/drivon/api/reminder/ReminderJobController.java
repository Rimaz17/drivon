package com.drivon.api.reminder;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import com.drivon.api.config.ReminderJobProperties;
import com.drivon.api.reminder.ReminderNotifier.RunSummary;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/**
 * Starts the daily reminder run. Render's free instance sleeps, so an in-process schedule would
 * miss days; a scheduled GitHub Actions workflow calls this instead, with a shared secret. Calling
 * it more than once a day is harmless.
 */
@RestController
@Tag(name = "Jobs", description = "Internal endpoints called by scheduled workflows")
class ReminderJobController {

  static final String PATH = "/internal/reminders/run";
  static final String SECRET_HEADER = "X-Drivon-Job-Secret";

  private static final Logger log = LoggerFactory.getLogger(ReminderJobController.class);

  private final ReminderNotifier notifier;
  private final ReminderJobProperties properties;

  ReminderJobController(ReminderNotifier notifier, ReminderJobProperties properties) {
    this.notifier = notifier;
    this.properties = properties;
  }

  @PostMapping(PATH)
  @Operation(
      summary = "Send due reminder notifications",
      description =
          "Pushes every reminder stage (due soon, due) not sent yet, across all users. Needs the"
              + " shared secret in the X-Drivon-Job-Secret header; not for the app.")
  @ApiResponse(responseCode = "200", description = "How many reminders were checked and notified")
  @ApiResponse(responseCode = "401", description = "UNAUTHENTICATED (missing or wrong secret)")
  @ApiResponse(responseCode = "404", description = "NOT_FOUND (no secret configured)")
  RunSummary run(
      @Parameter(hidden = true) @RequestHeader(name = SECRET_HEADER, required = false)
          @Nullable String secret) {
    if (!properties.enabled()) {
      throw new DrivonException(ErrorCode.NOT_FOUND);
    }
    if (secret == null
        || !MessageDigest.isEqual(
            properties.secretBytes(), secret.strip().getBytes(StandardCharsets.UTF_8))) {
      throw new DrivonException(ErrorCode.UNAUTHENTICATED, "Missing or wrong job secret.");
    }
    RunSummary summary = notifier.notifyAllDue();
    log.info(
        "Reminder run: {} checked, {} notified, {} failed",
        summary.checked(),
        summary.notified(),
        summary.failed());
    return summary;
  }
}
