# Drivon API (backend)

Spring Boot 4.1 REST API on Java 17. Base path for feature endpoints: `/api/v1`.

## Commands

All commands run from `backend/` (Git Bash on Windows: use `./mvnw`).

| Task | Command |
|---|---|
| Run against local Docker Postgres | `docker compose up -d postgres` (repo root), then `./mvnw spring-boot:run` |
| Run with a throwaway Testcontainers Postgres | `./mvnw spring-boot:test-run` |
| Full check (format + tests) | `./mvnw verify` |
| Fix formatting | `./mvnw spotless:apply` |
| Tests only | `./mvnw test` |
| Build the Docker image | `docker build -t drivon-api .` |

Docker must be running for the integration tests (Testcontainers starts `postgres:17.11-alpine` and `adobe/s3mock:5.2.3`, a local S3-compatible server that stands in for Cloudflare R2).

### Running from IntelliJ IDEA

1. *File → Open* the `backend/` folder (or its `pom.xml`) and open it as a Maven project.
2. *File → Project Structure → Project → SDK*: choose a Java 17 JDK.
3. Start Postgres: `docker compose up -d postgres` from the repo root (Docker Desktop must be running).
4. Run `DrivonApplication` (green arrow next to `main`). No profile or environment variables are needed: `dev` is the default and has a local-only database and JWT configuration.
   - To use documents, add the R2 variables to the run configuration (*Run → Edit Configurations… → Environment variables*): `R2_ACCOUNT_ID=…;R2_ACCESS_KEY_ID=…;R2_SECRET_ACCESS_KEY=…;R2_BUCKET=…`. Keep *Store as project file* unchecked so the secret never lands in the repo. Without them, document endpoints answer `503 STORAGE_UNAVAILABLE`.
   - To send push notifications, also add `FIREBASE_SERVICE_ACCOUNT_BASE64` (the Firebase service account JSON, Base64-encoded; see the root README). Without it, reminders still work and show in the app, but nothing is pushed.
   - For Ask My Vehicle, add `GEMINI_API_KEY` and/or `GROQ_API_KEY`. Without either, the chat endpoint answers `503 ASSISTANT_UNAVAILABLE`.
   - To start a reminder run by hand, `POST http://localhost:8080/internal/reminders/run` with the header `X-Drivon-Job-Secret: dev-only-reminders-job-secret-not-for-production` (the `dev` profile's built-in secret; Postman's *Reminders* folder has the request).
5. Alternatively run `TestDrivonApplication` (under `src/test`) to get a throwaway Testcontainers database instead of Docker Compose.

Swagger UI: <http://localhost:8080/swagger-ui.html>. Click *Authorize* and paste an `accessToken` from register or login.

## Profiles

| Profile | Used for | Database | JWT secret |
|---|---|---|---|
| `dev` (default) | Local development | `jdbc:postgresql://localhost:5433/drivon` unless `DB_URL`/`DB_USERNAME`/`DB_PASSWORD` are set | Built-in, publicly known dev key unless `JWT_SECRET` is set |
| `test` | Automated tests | Testcontainers (`@IntegrationTest`) | Fixed test key |
| `prod` | Render + Neon | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` required | `JWT_SECRET` required |

Document files go to Cloudflare R2 when `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and `R2_BUCKET` are set (required in `prod`, optional elsewhere). Tests use S3Mock instead.

Ask My Vehicle calls Google Gemini (`GEMINI_API_KEY`, model `GEMINI_MODEL`, default `gemini-3.6-flash`) and falls back to Groq (`GROQ_API_KEY`, model `GROQ_MODEL`, default `openai/gpt-oss-120b`). Both keys are required in `prod`; tests use scripted models and never call either provider.

Push notifications go through Firebase Cloud Messaging when `FIREBASE_SERVICE_ACCOUNT_BASE64` is set, and the daily reminder run needs `REMINDERS_JOB_SECRET` (at least 32 characters). Both are required in `prod`; `dev` has a built-in job secret and runs without Firebase. Tests record pushes instead of sending them.

The Docker image defaults to `prod`, so a misconfigured deploy fails at startup instead of silently using dev settings.

## Endpoints

| Method and path | Access | Notes |
|---|---|---|
| `POST /api/v1/auth/register` | Public, rate-limited | `{name, email, password}` → 201 with tokens |
| `POST /api/v1/auth/login` | Public, rate-limited | `{email, password}` → tokens |
| `POST /api/v1/auth/refresh` | Public | `{refreshToken}` → new tokens; the old refresh token is revoked |
| `POST /api/v1/auth/logout` | Public | `{refreshToken}` → 204 |
| `GET /api/v1/users/me` | Bearer | Signed-in profile |
| `GET /api/v1/vehicles` | Bearer | Own vehicles, oldest first (at most two) |
| `POST /api/v1/vehicles` | Bearer | 201 + `Location` |
| `GET/PUT/DELETE /api/v1/vehicles/{id}` | Bearer | 404 for missing *or someone else's* vehicle |
| `GET/POST /api/v1/vehicles/{id}/fuel-records` | Bearer | Paged fill-ups (newest first) / log a fill-up; an app-generated `id` makes retries return the saved record (200) |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/fuel-records/{recordId}` | Bearer | Closing full fills carry `kmPerLitre` |
| `GET /api/v1/vehicles/{id}/fuel-stats?from=&to=` | Bearer | Spend, litres, fill-ups, average/best/latest km/L, fuel cost per km (dates optional, inclusive) |
| `GET /api/v1/vehicles/{id}/fuel-stats/monthly?months=6` | Bearer | Fuel spend per month (1–24), oldest first, zero-filled |
| `GET/POST /api/v1/vehicles/{id}/maintenance-records` | Bearer | Paged services (`?serviceType=` filter) / log a service with optional odometer and next date/mileage |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/maintenance-records/{recordId}` | Bearer | A service's odometer follows it on the timeline |
| `GET /api/v1/vehicles/{id}/maintenance-records/upcoming` | Bearer | Next due service per type, with days/km remaining; overdue first |
| `GET/POST /api/v1/vehicles/{id}/expenses` | Bearer | Paged expenses (`?category=` filter) / log an expense |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/expenses/{expenseId}` | Bearer | |
| `GET /api/v1/vehicles/{id}/spending?from=&to=` | Bearer | Total and per-category spend; fill-ups count as FUEL, services as MAINTENANCE |
| `GET /api/v1/vehicles/{id}/spending/monthly?months=6` | Bearer | Total spend per month (1–24), oldest first, zero-filled |
| `GET /api/v1/spending/vehicles?from=&to=` | Bearer | Total spend of each of the user's vehicles |
| `GET/POST /api/v1/vehicles/{id}/documents` | Bearer | Paged confirmed documents (`?type=` filter) / start an upload: returns a pending document and a presigned `PUT` |
| `POST /api/v1/vehicles/{id}/documents/{documentId}/confirm` | Bearer | After uploading: checks the stored file and makes the document visible |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/documents/{documentId}` | Bearer | Details can be edited; delete also removes the file |
| `GET /api/v1/vehicles/{id}/documents/{documentId}/download-url` | Bearer | Presigned `GET`, valid for 5 minutes |
| `GET /api/v1/documents/expiring?withinDays=30` | Bearer | Documents expiring within 0–365 days (or already expired), across the user's vehicles |
| `GET /api/v1/vehicles/{id}/analytics/cost-per-km?from=&to=` | Bearer | Total cost ÷ distance driven, split into FUEL, MAINTENANCE and OTHER; `null` without distance |
| `GET /api/v1/vehicles/{id}/analytics/monthly-costs?months=6` | Bearer | Per month (1–24): fuel, maintenance, other, total, distance, cost per km |
| `GET /api/v1/vehicles/{id}/analytics/efficiency-trend?from=&to=` | Bearer | km/L and fuel cost per km of each full-to-full tank, oldest first |
| `GET /api/v1/analytics/vehicle-comparison?from=&to=` | Bearer | Each vehicle's distance, total, cost per km with its parts, and average km/L |
| `GET /api/v1/reminders?status=` | Bearer | All reminders across vehicles, most urgent first (`OVERDUE`, `DUE_SOON`, `UPCOMING` filter) |
| `GET/POST /api/v1/vehicles/{id}/reminders` | Bearer | A vehicle's reminders / add your own (title, due date and/or mileage) |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/reminders/{reminderId}` | Bearer | Only your own reminders can be changed; service and document reminders follow their records (`422 REMINDER_READ_ONLY`) |
| `PUT /api/v1/device-tokens` | Bearer | `{token, platform}` registers this installation for push → 204 |
| `DELETE /api/v1/device-tokens/{token}` | Bearer | Stop push to this installation (call before signing out) → 204 |
| `POST /api/v1/assistant/chat` | Bearer, 30 per user per day | `{message, vehicleId?, history?}` → `{reply}`; Ask My Vehicle answers from your data through read-only tools |
| `POST /internal/reminders/run` | `X-Drivon-Job-Secret` header | Daily reminder run, called by `.github/workflows/reminders-cron.yml`; idempotent |
| `GET/POST /api/v1/vehicles/{id}/odometer-readings` | Bearer | Odometer history (paged) / add a manual reading |
| `GET/PUT/DELETE /api/v1/vehicles/{id}/odometer-readings/{readingId}` | Bearer | Correct an initial or manual reading; delete a manual one |
| `GET /actuator/health`, `/actuator/info` | Public | Render health check |
| `GET /v3/api-docs`, `/swagger-ui.html` | Public | API documentation |

Tokens: access tokens are 15-minute JWTs sent as `Authorization: Bearer <token>`; refresh tokens last 30 days and rotate on each use (`docs/adr/0005-authentication-tokens.md`). A Postman collection is in `docs/api/`.

### Data conventions

- **Decimals are strings.** Money, litres and ratios are written as JSON strings such as `"10950.00"`, so no client turns them into floating point; requests may send strings or numbers.
- **Dates** are ISO calendar dates (`2026-10-07`) in Sri Lankan time; record dates can't be in the future. Months are `2026-10`. Timestamps (`createdAt`) are UTC instants.
- **Lists** return `{content, page, size, totalElements, totalPages, hasNext}`. Use `page` (from 0), `size` (default 20, at most 100) and `sort=field,asc|desc` with the fields listed in Swagger; other fields give `400 INVALID_SORT`.
- **Odometer timeline** (`docs/adr/0007-odometer-timeline.md`): readings can't be lower than one on an earlier date or higher than one on a later date (`422 ODOMETER_OUT_OF_ORDER`, with `minKm`/`maxKm`). The vehicle's current odometer is its highest reading. A mistyped initial or manual reading is fixed with `PUT …/odometer-readings/{readingId}`.
- **Spending** (`docs/adr/0009-maintenance-expenses-and-spending.md`) adds fill-ups and services to expenses, so a cost is entered once. Services may set a next date (after the service) and next mileage (above its odometer).
- **Documents** (`docs/adr/0011-documents-on-r2.md`): JPEG, PNG or PDF up to 5 MB, at most 100 per vehicle. Send the file to the presigned URL with exactly the headers returned, without the `Authorization` header, then confirm. Resending the same `id` resumes an upload.
- **Analytics** (`docs/adr/0012-analytics-and-cost-per-km.md`): distance driven comes from the odometer timeline (the highest reading at each end of the period). Cost per km is everything spent in the period over that distance; repairs count as maintenance, and insurance, parking, tolls, washing and other as OTHER.
- **Reminders** (`docs/adr/0013-reminders-and-notifications.md`): one reminder per service type (from the latest service that sets a next date or mileage) and per document type (latest expiry), plus your own. A reminder with a date and a mileage is due at whichever comes first; it is due soon 7 days ahead (30 for documents) or 500 km ahead. Each stage (due soon, due) is pushed once, by the daily run or right after an odometer change.
- **Ask My Vehicle** (`docs/adr/0014-ask-my-vehicle.md`): the model picks from 20 read-only tools; the server runs them for the signed-in user only and caps a question at 5 tool rounds and 60 seconds. `503 ASSISTANT_UNAVAILABLE` when both providers fail, `422 ASSISTANT_INCOMPLETE` when the model doesn't finish.
- **Fuel efficiency** uses the full-tank method (`docs/adr/0008-fuel-records-and-efficiency.md`). A price per litre that is sent must match amount ÷ litres to within 1% (at least Rs. 1), or it is left out and derived.

### Errors

Every error is an RFC 9457 Problem Details body (`application/problem+json`) with a stable `code` and the `requestId`:

```json
{
  "type": "about:blank",
  "title": "Vehicle limit reached",
  "status": 422,
  "detail": "You can add up to 2 vehicles.",
  "code": "VEHICLE_LIMIT_REACHED",
  "requestId": "9b1c…"
}
```

Validation failures (`VALIDATION_FAILED`, 400) add `errors: [{field, message}]`. All codes are listed in `common/error/ErrorCode.java`. Every response carries an `X-Request-Id` header, which also appears in each log line for that request.

## Conventions

- Package by feature under `com.drivon.api` (`auth`, `user`, `vehicle`, ...), with `common` and `config` for shared code. Each feature uses clearly named classes: `XController`, `XService`, `XRepository`, entity `X`, `XRequest`/`XResponse` records and `XMapper`.
- Controller → Service → Repository; DTOs are records; entities never leave the service layer.
- The user ID always comes from the token via `@CurrentUserId`, and every query is scoped to it.
- Schema changes only through Flyway migrations in `src/main/resources/db/migration`; Hibernate runs with `ddl-auto=validate`. Never edit a committed migration.
- Money is `BigDecimal` / `NUMERIC(12,2)`; timestamps are UTC `Instant`; time-dependent logic uses the injected `Clock`, and calendar dates come from `BusinessCalendar` (Asia/Colombo).
- Records the app may create offline extend `AssignedIdEntity`, so a client-generated UUID is accepted and a reused one fails instead of overwriting a row.
- google-java-format is enforced by Spotless. The formatter is pinned to 1.28.0, the newest version Spotless supports on Java 17.
