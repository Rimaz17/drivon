# Final iPhone test

The one hands-on iOS test of the MVP (project overview, section 7), done on a borrowed Mac with a real iPhone and a free Apple ID. CI has compiled the iOS app on every change; this session checks that it also *runs* correctly. Plan on about two hours, including setup.

## Before the session

- [ ] The API is deployed over HTTPS, with R2, Gemini/Groq and the reminders secret configured. iOS refuses plain HTTP (no App Transport Security exceptions are declared), so a laptop running the API locally can't be used.
- [ ] `main` is green in GitHub Actions, including *Build iOS (no codesign)*.
- [ ] A throwaway account can be created on the deployed API (or reuse a test account with no real data).
- [ ] On the iPhone: a sample PDF in the *Files* app (under 5 MB), and Wi-Fi you can switch off with airplane mode.
- [ ] Bring a USB cable that fits both the Mac and the iPhone.

## Setup on the Mac

Follow [Running on an iPhone](../../frontend/README.md#running-on-an-iphone-borrowed-mac-free-apple-id) in the frontend README: Xcode, Flutter 3.44.7, signing with a personal team, Developer Mode, then:

```bash
cd frontend
flutter run --release --dart-define=API_BASE_URL=https://<deployed-api>
```

Notes:

- *Developer Mode* only appears in the iPhone's settings after the phone has been connected to Xcode once.
- With a free Apple ID the app stops opening after 7 days; that's expected.
- If the build fails, copy the full error from the terminal before changing anything; the fix goes into the repo afterwards (from Windows), not only on the Mac.

## Checklist

Tick each item, and note anything odd (with a screenshot) in the results table at the end.

### 1. Account and session

- [ ] The launch animation plays on the dark canvas; no white flash before it.
- [ ] *Create account* works; the keyboard doesn't cover the fields or the button.
- [ ] Sign out, then sign in again.
- [ ] Swipe the app away in the app switcher and open it again: still signed in, straight to the Garage.

### 2. Vehicles and records

- [ ] Add a car and a motorbike; the vehicle switcher appears and switches between them.
- [ ] Fuel: log two full fill-ups and a partial one in between; km/L and cost per km appear after the second full fill-up.
- [ ] The date field opens the iOS wheel picker (not the Android calendar).
- [ ] Service: log a service with a next service date; it shows under upcoming services.
- [ ] Expenses: log an expense; the period switch and category totals update.
- [ ] Odometer history opens from the Garage and lists the readings.
- [ ] Pull to refresh shows the iOS spinner on the lists.

### 3. Documents (R2)

- [ ] *Take photo*: iOS asks for camera access with Drivon's explanation; allow it and photograph a document.
- [ ] The photo uploads (progress shows), then opens again from the list with pinch-to-zoom.
- [ ] *Choose PDF*: pick the sample PDF from *Files*; it uploads, and opening it shows the PDF in the system viewer.
- [ ] Deny camera access once (*Settings → Drivon → Camera* off): the app explains how to allow it instead of crashing.

### 4. Charts and layout

- [ ] Insights (chart button in the Garage app bar): every chart draws; tapping a bar or point shows its value.
- [ ] Nothing sits under the notch / Dynamic Island or the status bar.
- [ ] The tab bar sits above the home indicator, and the last item of a long list can be scrolled fully into view.
- [ ] Larger text (*Settings → Accessibility → Display & Text Size → Larger Text*, two steps up): screens still fit; figures shrink rather than cut off.
- [ ] Confirmation dialogs (deleting a record, signing out) look like iOS alerts.

### 5. Notifications (local)

- [ ] Garage → Reminders → *Turn on notifications*: the iOS permission prompt appears; allow it.
- [ ] The panel says notifications are on for date reminders.
- [ ] *Send a test*: the banner appears, also while Drivon is open.
- [ ] Tapping the test notification opens Drivon.

Real reminders are scheduled for 09:00 Sri Lanka time on their due-soon and due days, so they can't be watched in a short session. The test notification goes through the same plugin and permission, which is what this section proves.

### 6. Ask My Vehicle

- [ ] Ask tab: tap an example question; an answer arrives with the right figures (compare with the Fuel tab).
- [ ] Ask a follow-up ("And the motorbike?"); the answer uses the earlier question.
- [ ] Ask something off-topic (for example a recipe): the assistant politely declines.

### 7. Offline

- [ ] With the tabs opened once online, turn on airplane mode: the offline banner shows and saved data is still visible.
- [ ] Log a fill-up: it's saved on the phone and listed under *Waiting to sync*.
- [ ] Turn airplane mode off: the fill-up syncs and the Fuel figures update without duplicates.

### 8. Clean up

- [ ] Profile → *Delete account* with the throwaway account's password; the sign-in screen says the account was deleted.

## While the app is on the iPhone

Take the iOS screenshots for the README (list in [`docs/screenshots`](../screenshots/README.md)) and, if planned, record the iPhone part of the demo video.

## Results

| Section | Result | Notes / issue |
|---|---|---|
| 1. Account and session | | |
| 2. Vehicles and records | | |
| 3. Documents | | |
| 4. Charts and layout | | |
| 5. Notifications | | |
| 6. Ask My Vehicle | | |
| 7. Offline | | |

Device: ______ · iOS version: ______ · Date: ______ · Commit: ______

Fix any issue found on a `fix/...` branch, and re-check it on the iPhone if the Mac is still available.
