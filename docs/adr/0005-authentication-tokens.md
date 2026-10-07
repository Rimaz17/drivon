# 5. Authentication: short-lived JWTs with rotating refresh tokens

- Status: Accepted
- Date: 2026-10-07

## Context

The API is stateless (it runs on one Render instance that restarts and sleeps) and serves a mobile app that should stay signed in for weeks without storing the password. Tokens must be revocable on logout, and a stolen token should have limited value. The overview's data model has no table for sessions, so storing refresh tokens is a refinement of it.

## Decision

- **Access token:** a JWT signed with HS256, valid for **15 minutes**. Claims are only `iss` (`drivon-api`), `sub` (user ID), `iat` and `exp`. It is verified by Spring Security's OAuth2 resource server (signature, expiry with 60 s skew, issuer). The secret comes from `JWT_SECRET` (Base64, at least 256 bits) and is checked at startup. The API both issues and consumes the tokens, so a shared secret is simpler than a key pair.
- **Refresh token:** 256 random bits, Base64url, valid for **30 days**. Only the **SHA-256 hash** is stored, in a new `refresh_tokens` table (`user_id`, `family_id`, `token_hash`, `expires_at`, `revoked_at`, `created_at`).
- **Rotation:** every `/auth/refresh` revokes the presented token and issues a new pair in the same **family** (one family per login). The lookup takes a row lock, so two concurrent refreshes cannot both succeed.
- **Reuse detection:** presenting an already-revoked token revokes the whole family, because the token may have been stolen. The transaction is committed even though the request fails.
- **Logout** revokes the family of the presented refresh token. It is idempotent and needs no access token.
- **Passwords:** BCrypt (cost 10), 8–72 bytes. Login returns the same `INVALID_CREDENTIALS` error for an unknown email and a wrong password, and still runs a hash comparison for unknown emails so response times don't reveal which accounts exist.
- **Abuse:** register and login are rate-limited per client IP (10 attempts refilled over a minute, in memory) and return `429 RATE_LIMITED` with `Retry-After`.
- **User ID:** taken only from the verified token (`@CurrentUserId`), never from request bodies, paths or queries.
- The bearer header is ignored on `/api/v1/auth/**`, so an expired access token sent along with a refresh request can't cause a 401.
- The app keeps both tokens in the platform keystore (`flutter_secure_storage`) and refreshes once on a 401, never in parallel.

## Consequences

- A stolen access token works for at most 15 minutes. A stolen refresh token is caught on the next refresh by either party.
- If a refresh response is lost (for example a dropped connection) and the app retries with the old token, the user is signed out. That is an acceptable trade-off for a personal app, and the app limits it by refreshing only once at a time.
- Expired and revoked rows accumulate. A cleanup job can be added with the scheduled jobs in Phase 6.
- The overview's `User.fcmToken` is not added yet; device tokens arrive in Phase 6, likely as their own table (one user can have several devices).
- Rate-limit state lives in memory per instance and resets on restart, which is fine for a single free instance.
