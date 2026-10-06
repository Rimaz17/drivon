# 1. Stack baseline and repository layout

- Status: Accepted
- Date: 2026-10-07

## Context

Drivon is a solo, free-tier portfolio project with a Spring Boot API and a Flutter app for Android and iOS. Phase 0 needs a baseline that later phases can build on without churn, and that runs within Render's free instance (512 MB RAM, sleeps when idle) and Neon's free Postgres.

## Decision

- **Monorepo:** `backend/` (API), `frontend/` (app), `docs/`, `.github/` and shared root files in one repository, with path-filtered CI workflows so each side builds only when it changes.
- **Java 17 + Spring Boot 4.1.1.** Boot 4 still supports Java 17 as its baseline, and the developer has chosen to stay on 17. Language features and dependencies that need Java 21+ are off-limits.
- **Formatting:** Spotless with google-java-format **1.28.0**. Newer google-java-format releases need Java 21 and Spotless refuses to run them on 17. Revisit if Java is upgraded.
- **PostgreSQL 17** everywhere (Neon, Docker Compose, Testcontainers) so tests run on the production engine; no H2.
- **Security baseline:** stateless; only health, info and API docs are public, and everything else returns 401 until JWT auth lands in Phase 1. The auto-configured in-memory user is disabled so no generated password is logged.
- **Runtime image:** multi-stage Temurin 17 build, layered jar, non-root user, `-XX:MaxRAMPercentage=60` (about 300 MB heap on Render), `prod` as the default profile.
- **Flutter 3.44.7** pinned in CI. State management with Riverpod 3 and navigation with go_router; both are pure Dart and support Android and iOS.
- **App ID** `io.github.rimaz17.drivon`, a reverse domain the author controls.

## Consequences

- One pull request can change the API and the app together, while CI stays fast through path filters.
- The google-java-format pin lags upstream until Java is upgraded; formatting differences are minor.
- The Docker image refuses to start without production database variables, which is intentional.
