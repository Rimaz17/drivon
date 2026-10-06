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

## Profiles

| Profile | Used for | Database |
|---|---|---|
| `dev` (default) | Local development | `jdbc:postgresql://localhost:5432/drivon` unless `DB_URL`/`DB_USERNAME`/`DB_PASSWORD` are set |
| `test` | Automated tests | Testcontainers (`@IntegrationTest`) |
| `prod` | Render + Neon | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` required, with no defaults |

The Docker image defaults to `prod`, so a misconfigured deploy fails at startup instead of silently using dev settings.

## Endpoints

| Path | Access |
|---|---|
| `GET /actuator/health` | Public (Render health check) |
| `GET /actuator/info` | Public |
| `GET /v3/api-docs`, `/swagger-ui.html` | Public API documentation |
| everything else | Requires authentication (JWT from Phase 1) |

Every response carries an `X-Request-Id` header, which also appears in each log line for that request.

## Conventions

- Package by feature under `com.drivon.api` (`auth`, `vehicle`, `fuel`, ...), with `common` and `config` for shared code.
- Controller → Service → Repository; DTOs are records; entities never leave the service layer.
- Schema changes only through Flyway migrations in `src/main/resources/db/migration`; Hibernate runs with `ddl-auto=validate`.
- Money is `BigDecimal` / `NUMERIC(12,2)`; timestamps are UTC `Instant`.
- google-java-format is enforced by Spotless. The formatter is pinned to 1.28.0, the newest version Spotless supports on Java 17.
