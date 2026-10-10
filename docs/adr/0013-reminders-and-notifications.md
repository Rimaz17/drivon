# 13. Reminders and notifications

- Status: Accepted
- Date: 2026-10-10

## Context

Phase 6 adds smart reminders: date-based (insurance, revenue licence, service date) and mileage-based (oil change, tyre rotation, service interval). The overview's data model has a `Reminder` (vehicle, type date/mileage, due date, due km, status, `lastNotifiedAt`) and a single `fcmToken` on the user. Services already record a next date and mileage (ADR 0009) and documents an expiry date (ADR 0011).

Constraints: the free Render instance sleeps after 15 minutes, so an in-process daily schedule would miss days. Push to iPhones needs APNs, which needs the paid Apple Developer Program, so iOS gets local notifications only. A user can have more than one phone.

## Decision

### Reminders

- **One `reminders` table, three sources** (`source`):
  - `SERVICE`: one per service type, following the latest record of that type that sets a next date or mileage. Kept in step through `ServiceScheduleChangedEvent`, published inside the transaction of every service create, update and delete.
  - `DOCUMENT`: one per document type, following the visible document of that type that expires last, so a renewed policy replaces the expired one instead of leaving an overdue reminder behind. Kept in step through `DocumentsChangedEvent` (confirm, update, delete).
  - `MANUAL`: the user's own (title, due date and/or mileage; at most 50 per vehicle). Only these can be edited or deleted through the API (`422 REMINDER_READ_ONLY` otherwise).
  - Partial unique indexes allow at most one `SERVICE` reminder per service type and one `DOCUMENT` reminder per document type. Deleting a vehicle cascades.
- **Due date and mileage together:** a reminder may have both and is due at whichever comes first. This replaces the overview's single `type (date/mileage)` column.
- **Status is computed, not stored:** `OVERDUE` (past the date or mileage), `DUE_SOON` (within the lead time, including the due day) or `UPCOMING`. Lead times: 7 days for services and the user's own reminders, 30 days for documents (the app's existing "expiring soon" window) and 500 km for mileage. A finished manual reminder is deleted; an automatic one moves on when the next service is logged or the document is renewed. The response also carries `daysRemaining`, `kmRemaining` and `remindFrom` (the first due-soon day), so the app never repeats these rules.
- **Endpoints:** `GET /reminders?status=` across vehicles and `GET /vehicles/{id}/reminders`, both most urgent first and not paginated (bounded by the limits above); `POST`, `PUT`, `DELETE` for manual reminders, with client-generated IDs for idempotent retries.

### Notifications

- **Stages instead of a timestamp alone:** each reminder stores `notified_stage` (`NONE`, `DUE_SOON`, `DUE`) and `last_notified_at`. A run pushes only when the reminder's current stage is later than the stored one, then stores it. That makes runs idempotent and catch-up safe: a reminder that passed both stages while nothing ran gets only the `DUE` notification. Changing a due date or mileage resets the stage.
- **Triggers:**
  - Daily: `POST /internal/reminders/run` with the `X-Drivon-Job-Secret` header (`REMINDERS_JOB_SECRET`, at least 32 characters, compared in constant time). It is called by the scheduled `reminders-cron.yml` workflow. Without a configured secret the endpoint answers `404`.
  - Right away: `OdometerService` publishes `OdometerChangedEvent`; after the commit, the vehicle's reminders are checked, so a fill-up that crosses a mileage is pushed immediately. Failures there are logged and never fail the request.
  - Each reminder is processed in its own `REQUIRES_NEW` transaction with a row lock, so one failure doesn't undo others and two concurrent runs can't push the same stage twice.
- **Push (Android):** Firebase Admin SDK with the service account JSON in `FIREBASE_SERVICE_ACCOUNT_BASE64`. Firestore, Cloud Storage and Netty are excluded from the dependency to keep the image small. Messages go to channel `drivon_reminders` with the reminder ID as the tag, so the "due" notification replaces the "due soon" one. Tokens that FCM reports as `UNREGISTERED` or `SENDER_ID_MISMATCH` are deleted. A stage counts as sent when a device accepted it or the user has no devices; it stays open when FCM failed or push isn't configured.
- **Device tokens:** a `device_tokens` table (one row per installation) instead of `User.fcmToken`, because a user can have several phones. `PUT /device-tokens` registers (a token moves to whoever registered it last), `DELETE /device-tokens/{token}` unregisters, and only the newest 10 per user are kept.
- **App:**
  - On Android with push registered, reminders arrive by push.
  - Everywhere else (iOS, or Android without Firebase or without a token), the app schedules local notifications for date-based reminders at 9:00 Sri Lanka time on the `remindFrom` day and on the due day. It reschedules whenever reminders load and cancels them on sign-out.
  - Mileage reminders without push show in the app only.
  - Push messages that arrive while the app is open are shown through the same local notification channel.

## Consequences

- Reminders never drift from their records, and the user doesn't create the obvious ones by hand.
- Reminders depend on events being published by every write path; the integration tests cover create, update and delete for services and documents.
- The daily run depends on GitHub Actions; GitHub disables scheduled workflows after 60 days without repository activity. A missed day is caught up on the next run.
- On iPhones, date reminders work offline, and mileage reminders show only inside the app until APNs is set up.
