# Screenshots and demo video

Screenshots for the root README, taken from the release build against the deployed API, with realistic sample data (two vehicles, a few months of fill-ups, services, expenses and documents). Never show real personal data: use a throwaway account, made-up registration numbers and blank or sample documents.

## Files

Save PNGs at the phone's native resolution, one folder per platform, with the same names on both:

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
│   └── 08-reminders.png
└── ios/
    └── (the same eight names)
```

| File | Screen | Show |
|---|---|---|
| `01-garage` | Garage | Two vehicles (switcher visible), snapshot with km/L, cost per km, next service and this month's spend |
| `02-fuel` | Fuel tab | km/L gauge, fuel spend, recent fill-ups |
| `03-service` | Service tab | Next due service card and history |
| `04-ask` | Ask tab | A data question with its answer, e.g. "How much did I spend on fuel last month?" |
| `05-expenses` | Expenses tab | Period total, category split and vehicle comparison |
| `06-insights` | Insights | Cost per km with its fuel / maintenance / other parts and the monthly chart |
| `07-documents` | Documents | A list with an expiring document highlighted |
| `08-reminders` | Reminders | Overdue, due-soon and upcoming groups |

Android screenshots can be taken any time with the phone (*Power + Volume down*) or, in Git Bash, `adb exec-out screencap -p > 01-garage.png` (PowerShell 5 corrupts the redirected PNG). iOS ones are taken during the [final iPhone test](../testing/iphone-test-checklist.md) (*Side + Volume up*, then AirDrop them to the Mac).

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
