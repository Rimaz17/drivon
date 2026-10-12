# Deployment

How production runs and how changes reach it. The reasoning is in [ADR 0018](adr/0018-deployment.md).

## Production at a glance

| Part | Service | Where | Notes |
|---|---|---|---|
| API | Render free web service `drivon-api` (Docker, root directory `backend`) | Singapore | <https://drivon-api-vhtu.onrender.com> · health check `/actuator/health` · auto-deploy **off** |
| Database | Neon PostgreSQL 17, project `drivon`, database `neondb` | AWS Singapore (`ap-southeast-1`) | Direct connection (pooling off), `sslmode=require`; Flyway migrates at startup |
| Documents | Cloudflare R2 bucket `drivon-documents` | Automatic location | Private; token limited to this bucket (Object Read & Write) |
| Push | Firebase Cloud Messaging | — | Same Firebase project as development |
| AI | Google Gemini (primary), Groq (fallback) | — | Free tiers |
| Deploys and jobs | GitHub Actions | — | `deploy.yml`, `reminders-cron.yml`, `android-release.yml` |

Useful addresses (the first request after 15 idle minutes takes a minute or two while the instance wakes up):

- Health: <https://drivon-api-vhtu.onrender.com/actuator/health>
- Running version: <https://drivon-api-vhtu.onrender.com/actuator/info> (`app.commit` is the deployed commit)
- API documentation: <https://drivon-api-vhtu.onrender.com/swagger-ui.html> (the bare address redirects here)

## Configuration

### Render environment variables

Set in the Render dashboard (*drivon-api → Environment*). Never commit their values; `backend/.env.example` describes each one.

| Variable | Source |
|---|---|
| `DB_URL` | Neon *Connect* dialog, pooling off: `jdbc:postgresql://<host>/neondb?sslmode=require` |
| `DB_USERNAME`, `DB_PASSWORD` | Same dialog (`neondb_owner` and its password) |
| `JWT_SECRET` | Generated for production: `openssl rand -base64 48` |
| `REMINDERS_JOB_SECRET` | Generated for production: `openssl rand -hex 32` (also a GitHub secret, same value) |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | Cloudflare *R2* overview and the `drivon-prod` API token |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | `base64 -w 0` of the Firebase service account JSON |
| `GEMINI_API_KEY`, `GROQ_API_KEY` | Google AI Studio and Groq console |

Render sets `PORT` and `RENDER_GIT_COMMIT` itself; the Docker image selects the `prod` profile. A missing variable stops the API at startup with an error naming it.

After you change a variable, Render redeploys the service (or offers to when you save); the new value applies once it has restarted.

### GitHub secrets

*Settings → Secrets and variables → Actions*:

| Secret | Used by |
|---|---|
| `RENDER_DEPLOY_HOOK_URL` | `deploy.yml` (from *drivon-api → Settings → Deploy Hook*) |
| `DRIVON_API_URL` | `deploy.yml`, `reminders-cron.yml`, `android-release.yml` (`https://drivon-api-vhtu.onrender.com`, no trailing `/`) |
| `REMINDERS_JOB_SECRET` | `reminders-cron.yml` |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_SERVICES_JSON_BASE64` (optional) | `android-release.yml` (see the [frontend README](../frontend/README.md#release-apk)) |

## How a change goes live

| What changed | What happens after the pull request is merged |
|---|---|
| Backend (`backend/**`) | *Backend CI* runs on `main`; when it passes, *Deploy* calls Render for that exact commit and waits until `/actuator/info` shows it and health is `UP` (5–10 minutes). |
| App (`frontend/**`) | Nothing is deployed. Phones get the change from a new APK: tag a version (e.g. `v1.0.1`) and install it from the GitHub Release (frontend README → *Release APK*). |
| Docs only | Nothing is deployed. |

Database migrations ship with the backend: Flyway applies new `V…__*.sql` files when the new version starts. Never edit a migration that has run in production; add a new one.

Follow a deploy in *Actions → Deploy* on GitHub and in the service's *Logs* on Render.

## Common tasks

### Redeploy `main` without a code change

*Actions → Deploy → Run workflow* (branch `main`). Use it after a failed deploy caused by something outside the code, such as a missing variable that has since been added.

### Roll back a bad deploy

1. **Lasting fix:** revert the change on a branch (`git revert <commit>`), open a pull request, merge it. CI and *Deploy* ship the revert.
2. **Emergency, while that runs:** in Render, open *drivon-api → Deploys*, find the last good deploy, click **Rollback**, then *Rollback to this deploy*. It reuses that build, so it's quick. The next deploy from `main` replaces it, so still do step 1.

A rollback doesn't undo database migrations. If the bad change included a migration, fix forward with a new migration instead.

### Rotate a secret

- **JWT secret:** set a new `JWT_SECRET` in Render. Access tokens signed with the old key stop working, and the app quietly replaces them using its refresh token, so users stay signed in.
- **Reminders job secret:** change it in Render *and* in the GitHub secret, to the same value.
- **R2 token, AI keys, Firebase service account:** create the new one at the provider, update Render, then delete the old one at the provider.
- **Deploy hook:** if the URL leaks, use *Regenerate Hook* in Render and update `RENDER_DEPLOY_HOOK_URL`.

### Check that production works end to end

After the first deploy and after large changes, on a phone with the release build:

1. Create an account and add a vehicle.
2. Upload a document photo and open it again (checks R2).
3. Ask the assistant a question (checks Gemini/Groq).
4. Turn on notifications and send a test (checks the app side; push itself is checked by the daily run).
5. Delete the test account (*Profile → Delete account*).

Or run the [Postman collection](api/README.md#postman-collection) with `baseUrl` set to the production address, changing the job secret header as described there.

## Limits to keep in mind

- Render free: the instance sleeps after 15 idle minutes and takes a minute or two to wake; deploys cause a short outage; 750 free instance hours a month cover one always-on service.
- Neon free: about 0.5 GB of storage; the database suspends when idle and resumes on the first query.
- R2 free: 10 GB of storage and 1 million write operations a month; documents are capped at 5 MB each and 100 per vehicle.
- Gemini and Groq: daily request limits; the API also caps each user at 30 questions a day.
- GitHub disables scheduled workflows in a repository with no activity for 60 days; re-enable *Reminders* under *Actions* if that happens.

Check the Render, Neon and Cloudflare dashboards now and then: free tiers change over time.
