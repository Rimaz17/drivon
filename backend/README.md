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

Docker must be running for the integration tests (Testcontainers starts `postgres:17.11-alpine`).

### Running from IntelliJ IDEA

1. *File → Open* the `backend/` folder (or its `pom.xml`) and open it as a Maven project.
2. *File → Project Structure → Project → SDK*: choose a Java 17 JDK.
3. Start Postgres: `docker compose up -d postgres` from the repo root (Docker Desktop must be running).
4. Run `DrivonApplication` (green arrow next to `main`). No profile or environment variables are needed: `dev` is the default and has a local-only database and JWT configuration.
5. Alternatively run `TestDrivonApplication` (under `src/test`) to get a throwaway Testcontainers database instead of Docker Compose.

Swagger UI: <http://localhost:8080/swagger-ui.html>. Click *Authorize* and paste an `accessToken` from register or login.

## Profiles

| Profile | Used for | Database | JWT secret |
|---|---|---|---|
| `dev` (default) | Local development | `jdbc:postgresql://localhost:5433/drivon` unless `DB_URL`/`DB_USERNAME`/`DB_PASSWORD` are set | Built-in, publicly known dev key unless `JWT_SECRET` is set |
| `test` | Automated tests | Testcontainers (`@IntegrationTest`) | Fixed test key |
| `prod` | Render + Neon | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` required | `JWT_SECRET` required |

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
