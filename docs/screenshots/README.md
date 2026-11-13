# Screenshots and demo video

Screenshots for the root README, taken from the release build against the deployed API, with realistic sample data (two vehicles, a few months of fill-ups, services, expenses and documents). Never show real personal data: use a throwaway account, made-up registration numbers and blank or sample documents.

## Files

The README shows each screenshot inside a phone frame. Only the framed PNGs are committed, one folder per platform, with the same names on both:

```
docs/screenshots/
├── android/
│   ├── 01-garage.png
│   ├── 02-fuel.png
│   ├── 03-service.png
│   ├── 04-ask.png
│   ├── 05-expenses.png
│   ├── 06-insights.png
│   ├── 07-documents.png
│   ├── 08-reminders.png
│   ├── 09-profile.png
│   └── 10-notification.png   (Android only)
└── ios/
    └── 01-garage.png … 09-profile.png
```

| File | Screen | Show |
|---|---|---|
| `01-garage` | Garage | Two vehicles (switcher visible), snapshot with km/L, cost per km, next service and this month's spend |
| `02-fuel` | Fuel tab | km/L gauge, fuel spend, recent fill-ups |
| `03-service` | Service tab | Next due service card and history |
| `04-ask` | Ask tab | A data question with its answer, e.g. "How much did I spend on fuel this month?" |
| `05-expenses` | Expenses tab | Period total, category split and vehicle comparison |
| `06-insights` | Insights | Cost per km with its fuel / maintenance / other parts and the monthly chart |
| `07-documents` | Documents | Stored documents and their expiry |
| `08-reminders` | Reminders | Overdue, due-soon and upcoming groups |
| `09-profile` | Profile | Name and email (use an `example.com` address), sign out, delete account |
| `10-notification` | Notification shade | A reminder push notification (iOS has no push in the MVP) |

### Taking and framing them

1. Take full-screen portrait screenshots, status bar included. Android: *Power + Volume down*, or in Git Bash `adb exec-out screencap -p > 01-garage.png` (PowerShell 5 corrupts the redirected PNG). iOS: *Side + Volume up* during the [final iPhone test](../testing/iphone-test-checklist.md). Copy them to the computer without a messaging app if possible; WhatsApp shrinks and recompresses them.
2. Name each file as in the table, then frame them from `frontend/` (needs Pillow: `pip install pillow`):

   ```bash
   python tool/frame_screenshots.py android ../docs/screenshots/android path/to/01-garage.png path/to/02-fuel.png
   python tool/frame_screenshots.py ios ../docs/screenshots/ios path/to/01-garage.png path/to/02-fuel.png
   ```

   The iPhone frame adds a Dynamic Island and the Android frame a punch-hole camera, both drawn over the middle of the status bar, which the screenshots leave empty.

## Demo video

About 90 seconds, portrait, no sound needed (add captions instead):

1. Launch animation → Garage with two vehicles; switch between them.
2. Log a fill-up; km/L and cost per km update.
3. Insights: cost per km and the monthly chart.
4. Documents: photograph an insurance card, then open it again.
5. Reminders: turn on notifications and send a test.
6. Ask My Vehicle: two questions, one about fuel spend and one comparing the vehicles.
7. Airplane mode: log a fill-up offline, turn it off, watch it sync.

Record with the phone's built-in screen recorder. To show it in the README, drag the MP4 (under 10 MB for GitHub's editor) into the README on github.com, which uploads it and inserts a link that plays inline; or upload it to YouTube and link a thumbnail.
