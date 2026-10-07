# Drivon — Progress

## Current Status
- Current phase: Phase 1 — Auth & Vehicles (complete, awaiting review, merge and go-ahead for Phase 2)
- Current branch: `feat/phase-1-auth-vehicles` (local, not pushed); also `ci/dependabot-ignore-rules` (local, not pushed)
- Last updated: 2026-10-07

## Phase Checklist
- [x] Phase 0 — Setup
  - [x] Toolchain, repo hygiene, Spring Boot API skeleton, Docker/Compose, Flutter app, design system, CI, docs
  - [x] CI confirmed green on GitHub (Backend CI on push; Frontend CI incl. iOS via manual run)
- [x] Phase 1 — Auth & Vehicles
  - [x] Problem Details error handling with stable codes and request IDs
  - [x] Flyway V1 (users, refresh_tokens) and V2 (vehicles)
  - [x] JWT access tokens (HS256, 15 min) and rotating hashed refresh tokens with reuse detection (ADR 0005)
  - [x] Register / login / refresh / logout / `GET /users/me`, rate-limited register and login
  - [x] Vehicle CRUD: max 2 per user (row lock), odometer never decreases, per-user unique plates, ownership 404s (ADR 0006)
  - [x] Backend tests: unit, WebMvcTest, Testcontainers integration incl. cross-user isolation (73 tests)
  - [x] Postman collection for auth and vehicles; backend README (endpoints, errors, IntelliJ)
  - [x] Flutter: typed API errors, Dio client with single-flight token refresh, secure token storage
  - [x] Flutter: session state with launch restore, sign-in and create-account screens, session-aware routing
  - [x] Flutter: garage home with hero card and vehicle switcher, add/edit/delete form, remembered selection
  - [x] Flutter tests: unit, controller and widget tests (91 tests); CI generates models with build_runner
  - [x] Native audit fixes: tablet width caps, layout tokens, Android predictive back
  - [x] Dependabot ignores Java majors and SDK-pinned `intl` (separate branch)
- [ ] Phase 2 — Fuel Tracking
- [ ] Phase 3 — Maintenance & Expenses
- [ ] Phase 4 — Documents (Cloudflare R2)
- [ ] Phase 5 — Analytics & Cost/km
- [ ] Phase 6 — Reminders & Notifications
- [ ] Phase 7 — Ask My Vehicle (AI)
- [ ] Phase 8 — Offline Support
- [ ] Phase 9 — Deploy & Polish

## Next Steps
1. User pushes `ci/dependabot-ignore-rules` and `feat/phase-1-auth-vehicles`, opens PRs, waits for green CI (especially the iOS job), and merges.
2. User tests Phase 1 by hand on an Android phone (steps in `frontend/README.md`).
3. Tag `v0.1.0` after Phase 1 is merged (if the user approves).
4. Phase 2 (after go-ahead): odometer readings history (with an explicit correction flow), fuel records CRUD with client UUIDs, full-tank km/L, fuel cost/km, monthly and total fuel spend.

## Blockers / Questions for the User
- Pushing and merging are done by the user. Phase 1 CI has only run locally (same commands); the iOS build of the new plugins (secure storage, preferences) is first proven when the branch is pushed.
- Optional: install the GitHub CLI (`gh`) for PR work.

## Decisions
- 2026-10-07: App ID `io.github.rimaz17.drivon`; MIT license.
- 2026-10-07: Spring Boot 4.1.1 on Java 17; google-java-format pinned to 1.28.0 for Java 17 (see docs/adr/0001-stack-baseline-and-repository-layout.md).
- 2026-10-07: Hanken Grotesk replaces the commercial Sequel Sans (see docs/adr/0002-typeface-hanken-grotesk.md).
- 2026-10-07: Generated Dart code is not committed; CI runs build_runner (see docs/adr/0003-generated-code-is-not-committed.md).
- 2026-10-07: Primary color is the rendered swatch `#7D56EE`, not its `#E72068` label (see docs/adr/0004-design-tokens-from-inspiration.md).
- 2026-10-07: `.env.example` lives in `backend/`; the real `.env` stays at the repo root where Docker Compose reads it.
- 2026-10-07: Android `gradlew`/wrapper jar follow Flutter's default and are not committed.
- 2026-10-07: Auth uses 15-minute HS256 JWTs plus 30-day opaque refresh tokens, stored hashed, rotated in families with reuse detection (see docs/adr/0005-authentication-tokens.md).
- 2026-10-07: Fuel types are PETROL / DIESEL / HYBRID; EVs wait for kWh tracking. Odometer history and corrections arrive with Phase 2. The vehicle list is not paginated (capped at 2). The selected vehicle is kept on the device (see docs/adr/0006-vehicle-model.md).
- 2026-10-07: freezed is held at 3.2.5 (4.x needs Dart 3.13), which caps build_runner at 2.15.1.
- 2026-10-07: Phone testing uses `adb reverse tcp:8080 tcp:8080` so debug builds keep cleartext limited to localhost.

## Pinned Versions
- Java 17 (Temurin in CI and Docker: `eclipse-temurin:17.0.20_8-jdk-noble` / `-jre-noble`)
- Maven 3.9.16 via wrapper 3.3.4
- Spring Boot 4.1.1 (manages Spring Security 7.1, OAuth2 resource server/Nimbus, Hibernate, Flyway, Testcontainers 2.x, Caffeine, PostgreSQL driver)
- springdoc-openapi 3.1.1; Bucket4j (`bucket4j_jdk17-core`) 8.21.0
- Spotless Maven plugin 3.10.3, google-java-format 1.28.0
- PostgreSQL `postgres:17.11-alpine` (Compose and Testcontainers)
- Flutter 3.44.7 / Dart 3.12.2
- flutter_riverpod 3.4.3, go_router 18.0.2, intl 0.20.2, flutter_lints 6.0.0
- dio 5.11.1, flutter_secure_storage 11.2.0, shared_preferences 2.5.6
- freezed_annotation 3.1.0, json_annotation 4.12.0; dev: freezed 3.2.5, json_serializable 6.14.1, build_runner 2.15.1
- Hanken Grotesk 3.014 (OFL)
- GitHub Actions: checkout v7.0.1, setup-java v6.0.1, subosito/flutter-action v2.23.0, upload-artifact v7.0.1; runners ubuntu-24.04 and macos-latest

## Session Log
### 2026-10-07 (Phase 1)
- Done: full Phase 1 on `feat/phase-1-auth-vehicles`: backend auth and vehicles with error handling, rate limiting and tests; Flutter auth, session handling, garage and vehicle form with tests; docs, ADRs 0005 and 0006, Postman collection.
- Verified locally: `./mvnw verify` (73 tests incl. Testcontainers), live Docker smoke test of the dev profile (register → create vehicle → list; 401 Problem Details without a token), `flutter analyze` / `dart format` / `flutter test` (91 tests), `flutter build apk --debug`, actionlint.
- Notes: Windows builds failed in the Kotlin incremental compiler because the project (D:) and pub cache (C:) are on different drives; `kotlin.incremental=false` in `android/gradle.properties` fixes it. `freezed` 4 needs Dart 3.13, so 3.2.5 is used. Riverpod 3 retries failing providers by default; the vehicle list disables that so errors show a retry button. Light card tones re-theme text and icon buttons, because theme styles carry explicit light colors.

### 2026-10-07 (Phase 0)
- Done: Phase 0 end to end: backend skeleton with tests and Docker, Flutter app with design system, CI workflows, docs.
- Notes: converting `mvnw` tabs to spaces broke its heredoc under POSIX sh; restored the original and added an editorconfig rule. The theme contrast test caught a tertiary text color at 4.19:1, now raised to AA.
