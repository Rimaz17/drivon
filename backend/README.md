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
5. Alternatively run `TestDrivonApplication` (under `src/test`) to get a throwaway Testcontainers database instead of Docker Compose.

Swagger UI: <http://localhost:8080/swagger-ui.html>. Click *Authorize* and paste an `accessToken` from register or login.

## Profiles

| Profile | Used for | Database | JWT secret |
|---|---|---|---|
| `dev` (default) | Local development | `jdbc:postgresql://localhost:5433/drivon` unless `DB_URL`/`DB_USERNAME`/`DB_PASSWORD` are set | Built-in, publicly known dev key unless `JWT_SECRET` is set |
| `test` | Automated tests | Testcontainers (`@IntegrationTest`) | Fixed test key |
| `prod` | Render + Neon | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` required | `JWT_SECRET` required |

Document files go to Cloudflare R2 when `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and `R2_BUCKET` are set (required in `prod`, optional elsewhere). Tests use S3Mock instead.

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
