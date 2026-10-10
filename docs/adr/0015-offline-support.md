# 15. Offline support

- Status: Accepted
- Date: 2026-10-10

## Context

Phase 8 asks for an SQLite cache, draft fuel records, and sync when the phone is back online. Drivers often log a fill-up at a station with a poor signal. The free Render instance also sleeps, so the first request after a while can time out. The server must stay the single source of truth for every figure, and offline data must never leak between users on a shared phone.

## Decision

- **One local database** (`sqflite`, `drivon.db` in the app's private files) behind `LocalStore`, with two tables, both keyed by user ID:
  - `cache`: copies of API responses.
  - `drafts`: fill-ups waiting to sync.
  - Tokens stay in secure storage, never here.
  - Tests use an in-memory `LocalStore`, because SQLite doesn't run in widget tests.
- **Read cache in the HTTP client.** `OfflineCacheInterceptor` stores the JSON of every successful `GET` under `/api/v1/` for the signed-in user. When the server can't be reached (connection error, timeout or no socket), it answers the same `GET` from that copy. Repositories and screens don't change, and every screen that has been opened once works offline.
  - Download links (`…/download-url`) are not cached, because they expire.
  - Writes are never cached.
  - The next successful read replaces the copy, so the server stays authoritative.
- **Connection status:** the interceptor reports whether the last request reached the server. The tab shell shows "You're offline. Showing what was saved on this phone." until a request succeeds again. An answer with an error (404, 422) counts as reachable.
- **Fill-ups offline:**
  - `FuelMutations.add` generates the fill-up's UUID first. If the request fails with no connection or a timeout, the fill-up is kept as a draft with that ID and the form says it will sync later.
  - A timed-out request may have been saved. Sending it again is safe, because the API returns the existing record for a known ID (ADR 0008).
- **Sync queue** (`FuelSyncController`): sends waiting fill-ups oldest first when the phone gets a network (`connectivity_plus`), when a request succeeds again after being offline, at sign-in, and on *Sync now*.
  - Success deletes the draft and refreshes what the fill-up affects.
  - A refusal (4xx, for example an odometer out of order) keeps the draft with the server's reason, and it isn't sent again until the user taps *Try again*. The user can also discard it.
  - A server error or lost connection stops the run, to try again later.
  - The Fuel tab lists waiting fill-ups as entered, without km/L or totals, which only the server calculates.
- **Signing out:**
  - The user's cache and drafts are deleted. Unsynced fill-ups are listed in a warning first.
  - A session that expires keeps them for the same user's next sign-in. They can't be read by anyone else, because everything is keyed by user ID.
- Only fill-ups can be created offline, as the overview asks. Other edits need a connection and show the usual "can't reach Drivon" message.

## Consequences

- Offline reads show the last data the phone saw, which can be stale; the banner says so.
- The cache grows with the screens a user opens. That is a few hundred kilobytes for typical use, and it is cleared on sign-out.
- Conflicts are settled by the server's rules (odometer order, price check). The phone never overrides them.
