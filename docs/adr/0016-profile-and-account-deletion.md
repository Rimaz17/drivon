# 16. Profile editing, account deletion and the Ask tab

- Status: Accepted
- Date: 2026-10-11

## Context

Users could see their name and email in a small sheet from the Garage, but couldn't change them or remove their account. Removing an account must take everything with it, including document files in R2, and must not be possible with only an unlocked phone or a stolen access token. Separately, Ask My Vehicle was reachable only from the Garage, while Insights took a tab of its own; the assistant is the feature people come back to, so it deserves the tab.

## Decision

- **Profile update:** `PUT /api/v1/users/me` with `{name, email}`, the same rules as registration. The email is normalized and must stay unique (`409 EMAIL_ALREADY_REGISTERED`); changing only its case is allowed. No password is asked: the email is only a sign-in name, and there is no reset flow it could be used to take over.
- **Account deletion:** `POST /api/v1/users/me/deletion` with `{password}`, answering 204.
  - A POST rather than a DELETE with a body, because a body on DELETE has no defined meaning and proxies may drop it.
  - The password is checked again. A wrong one is `422 PASSWORD_INCORRECT`, not 401, so the app's token refresh doesn't treat it as an ended session. Checks are rate-limited per account with the sign-in limiter, so a stolen access token can't be used to guess the password.
  - `UserService.delete` publishes `UserDeletingEvent` and deletes the user row. Foreign keys cascade to refresh tokens, device tokens and vehicles, and from vehicles to all their records. `VehicleService` turns the event into a `VehicleDeletingEvent` per vehicle, so document files are deleted after commit exactly as when one vehicle is deleted.
- **App:**
  - The Garage account button opens a Profile page (a top-level route over the tabs) to edit the details, sign out, or delete the account in a dialog that asks for the password.
  - After a deletion the session ends with `SignedOut(accountDeleted: true)`, and the user's offline data and vehicle selection are cleared on the phone. The cleanup reads its dependencies before the sign-out, since the screen is gone by the time it runs.
  - Data providers depend on `currentUserIdProvider` instead of the whole user, so a new name doesn't reload every list or reset the selected vehicle.
- **Tabs:** Garage, Fuel, Service, Ask, Expenses. "Ask" keeps the label as short as its neighbours; the screen title stays "Ask My Vehicle". Insights moved to the Garage app bar, where the Ask button was.

## Consequences

- Deleting an account can't be undone; there is no grace period or soft delete. Access tokens issued before the deletion stay valid until they expire (at most 15 minutes) but find no data, and `/users/me` answers 401.
- If deleting a file in R2 fails after the commit, it is logged and orphaned, as with vehicle deletion.
- Password change is not part of this change.
