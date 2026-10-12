# Drivon API reference

The Drivon API is a REST API under `/api/v1`, with JSON bodies, bearer-token authentication and RFC 9457 Problem Details errors. Three views of it are kept up to date:

| What | Where | Best for |
|---|---|---|
| Swagger UI | `/swagger-ui.html` on a running API: [production](https://drivon-api-vhtu.onrender.com/swagger-ui.html) or <http://localhost:8080/swagger-ui.html> | Reading and trying endpoints in the browser |
| OpenAPI 3.1 description | [`openapi.json`](openapi.json) in this folder; live at `/v3/api-docs` (JSON) and `/v3/api-docs.yaml` | Tools, client generation, reading without running the API |
| Postman collection | [`drivon.postman_collection.json`](drivon.postman_collection.json) | Walking through every endpoint in order with checks |

The endpoint table, data conventions and error format are described in the [backend README](../../backend/README.md#endpoints).

## OpenAPI description

`openapi.json` is generated from the code, not written by hand: the operations, request and response schemas, validation limits and error codes come from the controllers and DTOs. `OpenApiSpecIntegrationTest` compares it with what the API serves on every build, so CI fails if an endpoint changes without the file. After changing an endpoint, regenerate it from `backend/`:

```bash
./mvnw test -Dtest=OpenApiSpecIntegrationTest -Dopenapi.write=true
```

Keys are sorted so the file doesn't change with the order in which Spring finds controllers, and the `servers` entry is left out because it names whichever host served the document.

To read it without running the API, import the file into [Swagger Editor](https://editor.swagger.io) (*File → Import file*) or Postman (*Import*).

Some things to know when reading it:

- **Authentication:** register or sign in under *Authentication* to get an access token (15 minutes) and a refresh token (30 days, replaced on every refresh). In Swagger UI, press *Authorize* and paste the access token; every other operation needs it.
- **Errors:** every 4xx and 5xx response is `application/problem+json` with the `Problem` schema. Branch on its `code`; each operation's error responses name the codes it returns.
- **Decimals** (money, litres, km/L) are strings such as `"18500.00"`.
- **Operation IDs** are stable and unique (`listFuelRecords`, `createVehicle`, …), so generated clients get readable method names.
- **Jobs:** `POST /internal/reminders/run` is for the scheduled reminders workflow and uses the `X-Drivon-Job-Secret` header instead of a token.

## Postman collection

1. *Import* `drivon.postman_collection.json`.
2. Set the collection variable `baseUrl`: `http://localhost:8080` (the default) or production, `https://drivon-api-vhtu.onrender.com` (allow a minute or two for the first request if it was asleep).
3. Run *Auth → Register* (the collection makes up an email the first time; clear the `email` variable for another account) or *Login*, then the folders from top to bottom, by hand or with the Collection Runner.

Test scripts check each response and store tokens and IDs (`vehicleId`, `fuelRecordId`, `documentId`, …) in collection variables for later requests. *Cleanup* deletes the vehicle and *Delete account* removes the test account.

Some folders need the matching backend settings:

- **Documents:** Cloudflare R2 (`R2_*`); without it the API answers `503 STORAGE_UNAVAILABLE`.
- **Ask My Vehicle:** `GEMINI_API_KEY` or `GROQ_API_KEY`; without them `503 ASSISTANT_UNAVAILABLE`.
- **Reminders → Run daily reminders (job):** the request sends the `dev` profile's built-in secret. Against any other environment, change the `X-Drivon-Job-Secret` header to that environment's `REMINDERS_JOB_SECRET`, and don't save it in the collection.
