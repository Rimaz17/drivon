# 14. Ask My Vehicle

- Status: Accepted
- Date: 2026-10-10

## Context

Phase 7 adds an assistant that answers questions in plain language from the user's own data (overview, section 6). It has to stay free: Google Gemini's free tier is the primary model and Groq's free tier (`openai/gpt-oss-120b`) is the fallback. Both rate-limit, and both can be slow or briefly unavailable. The model must never see or choose whose data it reads, and it must never be the source of numbers.

## Decision

- **Provider-neutral core.**
  - `LlmClient` has two implementations, `GeminiClient` (`generateContent` with function declarations) and `GroqClient` (OpenAI-compatible chat completions with `tools`). Both are plain `RestClient` calls; no SDKs.
  - Messages (`User`, `Assistant` with tool calls, `ToolResult`) and tools (`ToolSpec`: name, description, JSON Schema) are defined once and translated by each client. Gemini gets upper-case schema types.
  - Gemini's own model turn is kept and sent back unchanged, so its thought signatures survive tool calls.
  - Keys go in headers (`x-goog-api-key`, `Authorization: Bearer`), never in URLs.
- **Failover:**
  - `LlmRouter` asks the primary (`drivon.assistant.primary`, default `GEMINI`).
  - On any failure (network error, timeout, HTTP 429/5xx, a rejected request, an empty or blocked answer), it retries that call once with the other provider.
  - For the rest of that question it stays with the provider that worked, because neutral messages carry everything either side needs.
  - Models are configurable (`GEMINI_MODEL`, default `gemini-3.6-flash`; `GROQ_MODEL`, default `openai/gpt-oss-120b`), since free models change.
- **Twenty read-only tools** (`AssistantTools`), matching the overview's list: vehicles, odometer distance, fuel spend, history, efficiency, price trend, stations, service history, last and upcoming services, expenses, spending by category, period or month, cost per km, vehicle comparison, document status, expiring documents and reminders.
  - Each tool only turns arguments into a call to an existing service. New service methods were added where a range or aggregate was missing: fuel history, monthly price per litre, per-station totals, and service and expense history by date range. All of them are database queries.
  - Arguments are checked (`ToolArguments`): IDs, `YYYY-MM-DD` dates, bounded integers and enum choices. A bad value goes back to the model as `{"error": "..."}` so it can correct itself.
  - `vehicleId` is optional. It defaults to the vehicle selected in the app, else the only vehicle. If the user has two and none is selected, the model is asked to pick.
  - Dates default per tool: spend defaults to this month, history and efficiency to all time, and price trend to 12 months.
- **The user is never a tool argument.** The server builds a `ToolContext` from the access token. Every service call checks vehicle ownership, so a vehicle ID the model invents or copies from elsewhere gives "Vehicle not found". An integration test asks with another user's vehicle ID and checks nothing leaks.
- **Loop limits:**
  - At most 5 rounds of tool calls (`ASSISTANT_INCOMPLETE`, 422, when the model still wants more).
  - At most 8 calls per round; extra calls are answered with an error.
  - At most 60 seconds per question; each model call has a 25-second read timeout. Running out of time, or both providers failing, is `ASSISTANT_UNAVAILABLE` (503).
- **System prompt** (`AssistantPrompt`):
  - Gives today's date and the user's vehicles.
  - Data questions are answered only from tool results, never guessed.
  - General car-care answers start with "General advice:". Off-topic questions are declined in one sentence.
  - Write-requests are redirected to the app. The prompt, tools and IDs are never revealed.
  - Answers use `Rs. 18,500`, km/L, km and litres, in short plain text.
- **Stateless API:** `POST /api/v1/assistant/chat` takes the question (at most 1,000 characters), the selected `vehicleId` and up to 10 earlier turns. The server keeps no conversation, which suits Render restarts and keeps requests small.
- **Free-tier protection:** per-user token bucket (`drivon.assistant.rate-limit`, 30 questions refilled over 24 hours; `429 RATE_LIMITED` with `Retry-After`). Tool lists are capped at 50 items.
- **Configuration:** `GEMINI_API_KEY` and `GROQ_API_KEY`. Both are required in `prod`. Elsewhere either may be missing: the router skips a provider without a key, and with neither the endpoint answers `ASSISTANT_UNAVAILABLE`.
- **Tests never call a real provider.**
  - The clients are tested against `MockRestServiceServer`.
  - The router, loop, caps, failover, timeouts, rate limit and off-topic handling are tested with `ScriptedLlmClient`.
  - Integration tests run scripted models against real tools and Postgres.

## Consequences

- The model chooses lookups but never computes figures or sees other users' data.
- Each question costs one model call plus one per round of tool calls, so a typical question uses 2–3 calls of the free quota.
- Gemini's free tier may use prompts to improve Google's products; the app tells users not to share personal details in questions.
- Provider APIs evolve; the request formats live in two small classes with request-level tests, and failover covers one provider breaking.
