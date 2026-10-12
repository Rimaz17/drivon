# Drivon

**A personal vehicle companion for Android and iOS.** Drivon keeps every fill-up, service, expense, document and renewal for your vehicles in one place, then turns that data into the numbers that matter: real km/L, cost per kilometre, monthly spending and upcoming reminders. An in-app assistant, *Ask My Vehicle*, answers plain-language questions using your own data.

[![Backend CI](https://github.com/Rimaz17/drivon/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Rimaz17/drivon/actions/workflows/backend-ci.yml)
[![Frontend CI](https://github.com/Rimaz17/drivon/actions/workflows/frontend-ci.yml/badge.svg)](https://github.com/Rimaz17/drivon/actions/workflows/frontend-ci.yml)
[![Deploy](https://github.com/Rimaz17/drivon/actions/workflows/deploy.yml/badge.svg)](https://github.com/Rimaz17/drivon/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-violet.svg)](LICENSE)

> **Status:** the MVP features (Phases 0–8) are complete: accounts, two vehicles with an odometer history, fuel, services, expenses, documents on Cloudflare R2, Insights, reminders with notifications, the Ask My Vehicle assistant and offline use. The API is [live](#live-api) and deploys automatically after CI. Still to come in Phase 9: the first Android release, the final iPhone test, screenshots and a demo video; see the [roadmap](#roadmap).

## Features (MVP)

| Module | What it does |
|---|---|
| Vehicles | Up to 2 vehicles per user (make, model, year, registration, fuel type, odometer) with a switcher |
| Fuel tracking | Litres, amount, price/L, odometer, station, full or partial fill; km/L by the full-tank method, fuel cost per km, monthly and total fuel spend |
| Maintenance | Service history with next service date and mileage, and what is due next |
| Expenses | Fuel, maintenance, repairs, insurance, parking, tolls, washing and other; monthly/yearly/category totals |
| Analytics | Efficiency trends, monthly costs, category split and cost per km, with vehicle comparison |
| Documents | Insurance, revenue licence, registration, invoices and receipts stored privately in Cloudflare R2 |
| Smart reminders | Date-based and mileage-based reminders with push and local notifications |
| Ask My Vehicle | Natural-language questions answered through read-only backend tool calls on your real data |

Units are kilometres, litres and Sri Lankan Rupees (`Rs. 18,500`).

## Architecture

<p align="center">
  <img src="docs/architecture/drivon-architecture.png" alt="Drivon architecture: the Flutter app (Android and iOS) calls the Spring Boot API on Render over HTTPS with JWT; the API's feature modules use Gemini with Groq as fallback for Ask My Vehicle, PostgreSQL on Neon, Cloudflare R2 for documents and Firebase Cloud Messaging for push; GitHub Actions runs CI, deploys and the daily reminders job." width="720">
</p>

- **One app, two platforms:** a Flutter app for Android and iOS with an on-device SQLite cache, so saved data and new fill-ups work offline.
- **One API:** a Spring Boot modular monolith (package by feature, Controller → Service → Repository) in a Docker container on Render. It is the single source of truth for every figure: km/L, cost per km, totals and reminder dates.
- **Secrets stay on the server:** the database, AI, storage and Firebase credentials live only in the API's environment. The app holds none; document files go straight between the phone and R2 through short-lived signed URLs that the API hands out.
- **Ask My Vehicle:** the API gives Gemini (or Groq, if Gemini fails) 20 read-only tools and runs them for the signed-in user only, so answers come from the user's real data.

<details>
<summary>Text version of the diagram</summary>

```mermaid
flowchart TD
    app["Flutter app<br/>(Android + iOS)"] -- "HTTPS + JWT" --> api
    app --- local[("SQLite cache<br/>local notifications")]
    subgraph api["Spring Boot API (Render)"]
        direction LR
        c[Controller] --> s[Service] --> r[Repository]
    end
    r --> db[("PostgreSQL<br/>(Neon)")]
    s --> r2["Cloudflare R2<br/>(documents)"]
    app -. "signed upload / download" .-> r2
    s --> ai["Gemini Flash<br/>(Groq fallback)"]
    s --> fcm["Firebase Cloud Messaging"]
    gha["GitHub Actions"] -- "deploy after CI · daily reminders" --> api
```

</details>

## Live API

The API runs on Render's free tier at <https://drivon-api-vhtu.onrender.com>, which opens its [API documentation](https://drivon-api-vhtu.onrender.com/swagger-ui.html). The free instance sleeps after 15 idle minutes, so the first request after a quiet spell can take a minute or two. [`docs/deployment.md`](docs/deployment.md) describes production and how changes reach it.

## Install

Android: every tagged version publishes a signed APK on the repository's [Releases](https://github.com/Rimaz17/drivon/releases) page (built by the `Android release` workflow; see the [frontend README](frontend/README.md#release-apk)). Download it on the phone and open it to install.

iOS: there is no App Store or TestFlight build (both need the paid Apple Developer Program). The app runs on an iPhone from source with a free Apple ID; see [Running on an iPhone](frontend/README.md#running-on-an-iphone-borrowed-mac-free-apple-id).

## Tech stack

| Layer | Choice |
|---|---|
| Mobile | Flutter 3.44 (Dart 3.12), Riverpod, go_router, Material 3 with a custom dark design system |
| Backend | Java 17, Spring Boot 4.1, Spring Security (stateless JWT), Spring Data JPA, Flyway, springdoc-openapi |
| Database | PostgreSQL 17 (Neon in production, Docker locally) |
| Storage / AI / Push | Cloudflare R2, Google Gemini Flash + Groq, Firebase Cloud Messaging |
| Quality | JUnit 5, Mockito, Testcontainers, Spotless (google-java-format), flutter_lints, widget tests |
| Delivery | Docker, Docker Compose, GitHub Actions (API tests, Android build, iOS build, deploy to Render after CI, signed release APK, daily reminders run), Render (Singapore) |

## Getting started

### Prerequisites

- Java 17 (Temurin recommended)
- Flutter 3.44.7 (stable)
- Docker Desktop (for Postgres and the Testcontainers tests)
- Android Studio or an Android device for running the app

### Run the backend

```bash
cp backend/.env.example .env       # local-only values; never commit .env
docker compose up -d postgres      # Postgres 17 on localhost:5433
cd backend && ./mvnw spring-boot:run
```

Or run everything in containers with `docker compose up --build`. The API listens on <http://localhost:8080>:

- Health: <http://localhost:8080/actuator/health>
- Swagger UI: <http://localhost:8080/swagger-ui.html>

### Run the app

```bash
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs       # generated models are not committed
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator → host machine
```

On a USB-connected phone, run `adb reverse tcp:8080 tcp:8080` first and use `API_BASE_URL=http://localhost:8080`. The [frontend README](frontend/README.md#running-on-an-android-phone-from-android-studio) has step-by-step Android Studio instructions.

See [`backend/README.md`](backend/README.md) and [`frontend/README.md`](frontend/README.md) for details.

## Environment variables

All variables are listed with placeholders in [`backend/.env.example`](backend/.env.example) (copy it to `.env` at the repo root). Production values are set in Render and GitHub secrets ([`docs/deployment.md`](docs/deployment.md#configuration)).

| Variable | Used by | Purpose |
|---|---|---|
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT` | Docker Compose | Local database |
| `API_PORT` | Docker Compose | Host port for the containerised API |
| `SPRING_PROFILES_ACTIVE` | Backend | `dev` locally, `prod` on Render |
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Backend | Database connection (Neon needs `sslmode=require`) |
| `JWT_SECRET` | Backend | Base64 HS256 signing key (≥ 256 bits, `openssl rand -base64 48`); required in prod |
| `PORT` | Backend | HTTP port, injected by Render |
| `RENDER_GIT_COMMIT` | Backend | Set by Render to the deployed commit; shown as `app.commit` at `/actuator/info` (`local` elsewhere) |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | Backend | Cloudflare R2 bucket for documents; required in prod, optional locally (without them only document endpoints are unavailable) |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | Backend | Firebase service account JSON, Base64-encoded, for push notifications; required in prod, optional locally (reminders then show in the app only) |
| `REMINDERS_JOB_SECRET` | Backend, GitHub secret | Shared secret (≥ 32 characters) of the daily reminder run; required in prod. The `reminders-cron.yml` workflow also needs the `DRIVON_API_URL` secret |
| `GEMINI_API_KEY`, `GROQ_API_KEY` | Backend | Ask My Vehicle (Gemini primary, Groq fallback); required in prod, optional locally. `GEMINI_MODEL` and `GROQ_MODEL` override the models |

The Flutter app takes only non-secret build settings via `--dart-define` (`API_BASE_URL`).

## API documentation

The API is documented with OpenAPI 3.1 (see [`docs/api`](docs/api/README.md)):

- **Swagger UI** at `/swagger-ui.html` on a running API: [live](https://drivon-api-vhtu.onrender.com/swagger-ui.html), or <http://localhost:8080/swagger-ui.html> locally.
- **[`docs/api/openapi.json`](docs/api/openapi.json)**: the full description, generated from the code. A test fails the build when it no longer matches the API.
- **[Postman collection](docs/api/drivon.postman_collection.json)** that walks through every endpoint in order, with checks.

Errors are RFC 9457 Problem Details with a stable `code` (for example `VEHICLE_LIMIT_REACHED`); the [backend README](backend/README.md#endpoints) lists the endpoints and data conventions.

## Testing

```bash
cd backend && ./mvnw verify      # formatting check + unit + Testcontainers integration tests (Postgres, S3Mock) + OpenAPI spec check
cd frontend && flutter test      # unit and widget tests
```

CI runs the same checks on every push and pull request, builds a debug APK, and compiles the iOS app on a macOS runner without code signing. Manual checks are written down in [`docs/testing`](docs/testing): a [manual test guide for Phases 1–8](docs/testing/manual-test-guide-phases-1-8.pdf) with expected values, and the [final iPhone test](docs/testing/iphone-test-checklist.md) checklist.

## Project structure

```
drivon/
├── backend/            Spring Boot API (package-by-feature under com.drivon.api) + .env.example
├── frontend/           Flutter app (app/, core/, design_system/, features/)
├── docs/               ADRs, deployment runbook, architecture diagram, API reference (OpenAPI + Postman), brand assets, test guides, screenshots
├── .github/            CI, deploy, release and reminder workflows, Dependabot, PR template
└── docker-compose.yml  Local Postgres + API (reads .env from the repo root)
```

## Roadmap

| Phase | Focus | Status |
|---|---|---|
| 0 | Setup: repo, Spring Boot, Docker Compose, Flutter (Android + iOS), CI, design system | ✅ Done |
| 1 | Auth & vehicles | ✅ Done |
| 2 | Fuel tracking | ✅ Done |
| 3 | Maintenance & expenses | ✅ Done |
| 4 | Documents (Cloudflare R2) | ✅ Done |
| 5 | Analytics & cost per km | ✅ Done |
| 6 | Reminders & notifications | ✅ Done |
| 7 | Ask My Vehicle | ✅ Done |
| 8 | Offline support | ✅ Done |
| 9 | Deploy & polish | In progress |

Out of scope for the MVP: more than two vehicles, OCR, PDF/CSV export, assistant write actions, store publishing, shared vehicles and iOS push notifications.

## Design decisions

Significant decisions are recorded as ADRs in [`docs/adr/`](docs/adr/).

## License

[MIT](LICENSE) © 2026 Rimaz Saththar. Bundled Hanken Grotesk font: SIL Open Font License 1.1.
