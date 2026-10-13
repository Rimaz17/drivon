# 18. Production deployment

- Status: Accepted
- Date: 2026-10-13

## Context

The API has to run somewhere public, for free, in a way that survives the free tiers' limits: Render's free web service sleeps after 15 idle minutes and has 0.1 CPU and 512 MB of RAM, and Neon's free database suspends when idle. Only code that passed CI may go live, every secret must stay out of git, and the setup should be repeatable from the repository's documentation. Most users are in Sri Lanka.

## Decision

- **API:** a Render free web service (`drivon-api`, <https://drivon-api-vhtu.onrender.com>) built from `backend/Dockerfile` (root directory `backend`, Docker runtime) in **Singapore**, the nearest Render region. The image starts with the `prod` profile, which refuses to start if a required variable is missing. Render's health check uses `/actuator/health`.
- **Database:** Neon PostgreSQL 17 in AWS **Singapore** (`ap-southeast-1`), next to the API. The API uses Neon's **direct** connection rather than its connection pooler, because the API already pools its own connections (Hikari, at most 5) and Flyway's migrations should run on a plain database session, as they do locally. Hikari retires connections before Neon closes idle ones. Flyway migrates the schema at startup.
- **Documents:** a separate private R2 bucket, `drivon-documents`, with an API token limited to that bucket (Object Read & Write). The development bucket and its token are never used by production.
- **Secrets:** set as environment variables in the Render dashboard (database, JWT, R2, Firebase, Gemini, Groq, reminders job secret). GitHub holds only what workflows need: `RENDER_DEPLOY_HOOK_URL`, `DRIVON_API_URL` and `REMINDERS_JOB_SECRET`. Production uses its own JWT and job secrets, generated for it.
- **Deploys:** Render's auto-deploy is **off**. `.github/workflows/deploy.yml` runs when *Backend CI* succeeds for a push to `main`. It calls the Render deploy hook with `ref=<tested commit>`, so the commit CI tested is the one that ships even if `main` has moved on. It then waits until `/actuator/info` reports that commit (`info.app.commit`, from Render's `RENDER_GIT_COMMIT`) and health is `UP`. A manual run redeploys `main`.
- **Startup on 0.1 CPU:** the image runs the JVM with `-XX:TieredStopAtLevel=1` (C1 compiler only). Under a 0.1 CPU limit it started the API in 205–229 seconds instead of 484–621, because the optimizing C2 compiler no longer competes with startup; this API's load never needs C2's peak speed.
- **Bare address:** `GET /` redirects to Swagger UI, so the API's link leads to its documentation instead of a 401.
- **Scheduled work:** the daily reminders workflow (ADR 0013) calls the same API address; it retries while the instance wakes up.

## Consequences

- Only changes under `backend/` (or to the Backend CI workflow) deploy, because Backend CI only runs for those; app and docs changes don't restart the API.
- A deploy takes about 5–10 minutes: the build, then the start on 0.1 CPU (160 seconds before the JIT change below). Free instances have no zero-downtime deploys, so the API is briefly unavailable while it restarts; the app shows saved data meanwhile (ADR 0015).
- After 15 idle minutes the next request waits for a cold start: 95 seconds measured after the JIT change. The app waits up to 2 minutes for an answer, but launch only waits 10 seconds before carrying on with the cached profile, so returning users aren't stuck on the launch screen; a banner says the server is waking up (not that the phone is offline) until the first answer arrives.
- Render asks for a card on file to verify the account, even on the free plan; nothing is charged while the service stays on the free instance type.
- Schema migrations run before the new version serves traffic, so a migration must work with the version still running until the restart (add columns before using them, drop them a release later).
- Rolling back in the Render dashboard is quick (it reuses an earlier build) but leaves `main` ahead of what runs, so the next deploy would bring the bad change back. It's for emergencies; the lasting fix is reverting the commit on `main`, which goes through CI and the deploy workflow like any change (see `docs/deployment.md`).
- Moving off Render later (for example to an Oracle Cloud VM with Docker Compose) only changes the deploy workflow and the environment; the image and the profile stay the same.
