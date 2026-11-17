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
    └── 01-garage.png, 03-service.png … 09-profile.png
```

`ios/02-fuel.png` is missing on purpose: the earlier one showed test data (3,220 km/L) that read as a bug. Retake it with realistic fill-ups during the next iPhone test. `android/01-garage.png` and `android/02-fuel.png` were taken on the Pixel 9a emulator against the local API with sample data, with the screen set to the phone's size (`adb shell wm size 1080x2340`, then `adb shell wm size reset`) so their frames match the other Android screenshots.

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

The README's demo (about 3 minutes, landscape, voiceover, burned-in captions and music) walks through the Garage, logging a fill-up, the full-tank km/L method, Service, Expenses, Insights, Documents, Reminders, Ask My Vehicle, offline sync and the architecture. Every phone frame is a screenshot of the running app against the local API with sample data; forms were captured one keystroke at a time with the real keyboard.

It is not committed. GitHub only plays a video inline when it is uploaded through its own attachment uploader (under 10 MB on a free account), so the README links a `github.com/user-attachments` copy compressed to 720p. To replace it, drag the new MP4 into any comment box on github.com, copy the link GitHub inserts, and swap it into the README (a bare link on its own line renders as a player).

Music: "Inspired" by Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0.
