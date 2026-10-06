# Drivon — Progress

## Current Status
- Current phase: Phase 0 — Setup (complete, awaiting go-ahead for Phase 1)
- Current branch: main (local commits, not yet pushed)
- Last updated: 2026-10-07

## Phase Checklist
- [x] Phase 0 — Setup
  - [x] Toolchain verified: Java 17.0.12, Flutter 3.44.7 / Dart 3.12.2, Docker 29.2.1, Git 2.50.1 (gh CLI not installed)
  - [x] Repo hygiene: .gitignore, .gitattributes, .editorconfig, MIT license
  - [x] Spring Boot 4.1.1 API with dev/prod/test profiles, Spotless, request IDs, security baseline, OpenAPI
  - [x] Testcontainers (Postgres 17) integration tests
  - [x] Multi-stage Dockerfile and Docker Compose (Postgres + API), verified locally
  - [x] Flutter app for Android + iOS (`io.github.rimaz17.drivon`): Riverpod, go_router, l10n, strict lints
  - [x] Android debug-only cleartext config; app named Drivon on both platforms
  - [x] Design system: tokens, dark theme, Hanken Grotesk, base components, contrast tests
  - [x] CI: backend (verify + Docker build), frontend (analyze/test, Android APK, iOS no-codesign), linted with actionlint
  - [x] PR template, Dependabot
  - [x] README, backend/frontend READMEs, ADRs 0001–0004, Postman collection
  - [ ] CI confirmed green on GitHub (needs the user to push)
- [ ] Phase 1 — Auth & Vehicles
- [ ] Phase 2 — Fuel Tracking
- [ ] Phase 3 — Maintenance & Expenses
- [ ] Phase 4 — Documents (Cloudflare R2)
- [ ] Phase 5 — Analytics & Cost/km
- [ ] Phase 6 — Reminders & Notifications
- [ ] Phase 7 — Ask My Vehicle (AI)
- [ ] Phase 8 — Offline Support
- [ ] Phase 9 — Deploy & Polish

## Next Steps
1. User pushes `main` to GitHub; confirm Backend CI and Frontend CI (including the iOS job) pass.
2. Phase 1 backend: Flyway V1 (users, refresh tokens, vehicles), register/login/refresh/logout with JWT, ProblemDetail error handling, vehicle CRUD (max 2), auth rate limiting.
3. Phase 1 frontend: dio client + secure token storage, login/register screens, vehicle list/switcher; plan each screen's states and layout before building it.

## Blockers / Questions for the User
- Pushing is left to the user (agreed 2026-10-07); CI has only been validated locally (same commands, actionlint), not yet on GitHub runners.
- Optional: install the GitHub CLI (`gh`) to make PR-based work from Phase 1 onward smoother.

## Decisions
- 2026-10-07: App ID `io.github.rimaz17.drivon`; MIT license.
- 2026-10-07: Spring Boot 4.1.1 on Java 17; google-java-format pinned to 1.28.0 for Java 17 (see docs/adr/0001-stack-baseline-and-repository-layout.md).
- 2026-10-07: Hanken Grotesk replaces the commercial Sequel Sans (see docs/adr/0002-typeface-hanken-grotesk.md).
- 2026-10-07: Generated Dart code is not committed (see docs/adr/0003-generated-code-is-not-committed.md).
- 2026-10-07: Primary color is the rendered swatch `#7D56EE`, not its `#E72068` label (see docs/adr/0004-design-tokens-from-inspiration.md).
- 2026-10-07: Android `gradlew`/wrapper jar follow Flutter's default and are not committed (the Flutter tool regenerates them), so no executable bit is needed for them.

## Pinned Versions
- Java 17 (Temurin in CI and Docker: `eclipse-temurin:17.0.20_8-jdk-noble` / `-jre-noble`)
- Maven 3.9.16 via wrapper 3.3.4
- Spring Boot 4.1.1 (manages Spring Security, Hibernate, Flyway, Testcontainers 2.x, PostgreSQL driver)
- springdoc-openapi 3.1.1
- Spotless Maven plugin 3.10.3, google-java-format 1.28.0
- PostgreSQL `postgres:17.11-alpine` (Compose and Testcontainers)
- Flutter 3.44.7 / Dart 3.12.2
- flutter_riverpod 3.4.3, go_router 18.0.2, intl 0.20.2, flutter_lints 6.0.0
- Hanken Grotesk 3.014 (OFL)
- GitHub Actions: checkout v7.0.1, setup-java v6.0.1, subosito/flutter-action v2.23.0, upload-artifact v7.0.1; runners ubuntu-24.04 and macos-latest

## Session Log
### 2026-10-07
- Done: Phase 0 end to end: backend skeleton with tests and Docker, Flutter app with design system, CI workflows, docs.
- Verified locally: `./mvnw verify` (9 tests), Docker image + Compose smoke test (health UP, 401 on API, non-root, ~275 MiB), `flutter analyze` / `dart format` / `flutter test` (36 tests), `flutter build apk --debug`, actionlint on workflows.
- Notes: converting `mvnw` tabs to spaces broke its heredoc under POSIX sh; restored the original and added an editorconfig rule. The theme contrast test caught a tertiary text color at 4.19:1, now raised to AA.
