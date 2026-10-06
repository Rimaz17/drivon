# Drivon

**A personal vehicle companion for Android and iOS.** Drivon keeps every fill-up, service, expense, document and renewal for your vehicles in one place, then turns that data into the numbers that matter: real km/L, cost per kilometre, monthly spending and upcoming reminders. An in-app assistant, *Ask My Vehicle*, answers plain-language questions using your own data.

[![Backend CI](https://github.com/Rimaz17/drivon/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Rimaz17/drivon/actions/workflows/backend-ci.yml)
[![Frontend CI](https://github.com/Rimaz17/drivon/actions/workflows/frontend-ci.yml/badge.svg)](https://github.com/Rimaz17/drivon/actions/workflows/frontend-ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-violet.svg)](LICENSE)

> **Status:** Phase 0 (project setup) is complete. Features land phase by phase; see the [roadmap](#roadmap) and [`docs/PROGRESS.md`](docs/PROGRESS.md).

## Features (MVP)

| Module | What it does |
|---|---|
| Vehicles | Up to 2 vehicles per user (make, model, year, registration, fuel type, odometer) with a switcher |
| Fuel tracking | Litres, amount, price/L, odometer, station, full or partial fill; km/L by the full-tank method |
| Maintenance | Service history with next service date and mileage |
| Expenses | Fuel, maintenance, repairs, insurance, parking, tolls, washing and other; monthly/yearly/category totals |
| Analytics | Efficiency trends, monthly costs, category split and cost per km, with vehicle comparison |
| Documents | Insurance, revenue licence, registration, invoices and receipts stored privately in Cloudflare R2 |
| Smart reminders | Date-based and mileage-based reminders with push and local notifications |
| Ask My Vehicle | Natural-language questions answered through read-only backend tool calls on your real data |

Units are kilometres, litres and Sri Lankan Rupees (`Rs. 18,500`).

## Architecture

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
    s --> ai["Gemini Flash<br/>(Groq fallback)"]
    s --> fcm["Firebase Cloud Messaging"]
```

The app only talks to the API. Every secret (database, AI, storage, Firebase) lives in backend environment variables; nothing sensitive ships inside the app. The backend is the single source of truth for all calculations.

## Tech stack

| Layer | Choice |
|---|---|
| Mobile | Flutter 3.44 (Dart 3.12), Riverpod, go_router, Material 3 with a custom dark design system |
| Backend | Java 17, Spring Boot 4.1, Spring Security (stateless JWT), Spring Data JPA, Flyway, springdoc-openapi |
| Database | PostgreSQL 17 (Neon in production, Docker locally) |
| Storage / AI / Push | Cloudflare R2, Google Gemini Flash + Groq, Firebase Cloud Messaging |
| Quality | JUnit 5, Mockito, Testcontainers, Spotless (google-java-format), flutter_lints, widget tests |
| Delivery | Docker, Docker Compose, GitHub Actions (API tests, Android build, iOS build), Render |

## Getting started

### Prerequisites

- Java 17 (Temurin recommended)
- Flutter 3.44.7 (stable)
- Docker Desktop (for Postgres and the Testcontainers tests)
- Android Studio or an Android device for running the app

### Run the backend

```bash
cp .env.example .env               # local-only values; never commit .env
docker compose up -d postgres      # Postgres 17 on localhost:5432
cd backend && ./mvnw spring-boot:run
```

Or run everything in containers with `docker compose up --build`. The API listens on <http://localhost:8080>:

- Health: <http://localhost:8080/actuator/health>
- Swagger UI: <http://localhost:8080/swagger-ui.html>

### Run the app

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator → host machine
```

See [`backend/README.md`](backend/README.md) and [`frontend/README.md`](frontend/README.md) for details.

## Environment variables

All variables are listed with placeholders in [`.env.example`](.env.example).

| Variable | Used by | Purpose |
|---|---|---|
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT` | Docker Compose | Local database |
| `API_PORT` | Docker Compose | Host port for the containerised API |
| `SPRING_PROFILES_ACTIVE` | Backend | `dev` locally, `prod` on Render |
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Backend | Database connection (Neon needs `sslmode=require`) |
| `PORT` | Backend | HTTP port, injected by Render |

The Flutter app takes only non-secret build settings via `--dart-define` (`API_BASE_URL`).

## Testing

```bash
cd backend && ./mvnw verify      # formatting check + unit + Testcontainers integration tests
cd frontend && flutter test      # unit and widget tests
```

CI runs the same checks on every push and pull request, builds a debug APK, and compiles the iOS app on a macOS runner without code signing.

## Project structure

```
drivon/
├── backend/            Spring Boot API (package-by-feature under com.drivon.api)
├── frontend/           Flutter app (app/, core/, design_system/, features/)
├── docs/               Progress log, ADRs, API collection, screenshots
├── .github/            CI workflows, Dependabot, PR template
├── docker-compose.yml  Local Postgres + API
└── .env.example        Every environment variable, with placeholders
```

## Roadmap

| Phase | Focus | Status |
|---|---|---|
| 0 | Setup: repo, Spring Boot, Docker Compose, Flutter (Android + iOS), CI, design system | ✅ Done |
| 1 | Auth & vehicles | Next |
| 2 | Fuel tracking | |
| 3 | Maintenance & expenses | |
| 4 | Documents (Cloudflare R2) | |
| 5 | Analytics & cost per km | |
| 6 | Reminders & notifications | |
| 7 | Ask My Vehicle | |
| 8 | Offline support | |
| 9 | Deploy & polish | |

Out of scope for the MVP: more than two vehicles, OCR, PDF/CSV export, assistant write actions, store publishing, shared vehicles and iOS push notifications.

## Design decisions

Significant decisions are recorded as ADRs in [`docs/adr/`](docs/adr/).

## License

[MIT](LICENSE) © 2026 Rimaz Saththar. Bundled Hanken Grotesk font: SIL Open Font License 1.1.
