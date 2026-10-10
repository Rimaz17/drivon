# Drivon app (frontend)

Flutter app for Android and iOS. Requires **Flutter 3.44.7** (stable, Dart 3.12.2), the same version CI uses.

## First-time setup

Generated code is not committed (`docs/adr/0003-generated-code-is-not-committed.md`), so after cloning, and whenever a model or ARB file changes, run from `frontend/`:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`flutter pub get` generates the localization code; `build_runner` generates the `*.freezed.dart` and `*.g.dart` model files.

## Commands

Run from `frontend/`.

| Task | Command |
|---|---|
| Install packages (also generates localization code) | `flutter pub get` |
| Generate models | `dart run build_runner build --delete-conflicting-outputs` |
| Run on the Android emulator against a local API | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080` |
| Run on a USB-connected Android phone | `adb reverse tcp:8080 tcp:8080`, then `flutter run --dart-define=API_BASE_URL=http://localhost:8080` |
| Format | `dart format .` |
| Analyze | `flutter analyze` |
| Test | `flutter test` |
| Debug APK | `flutter build apk --debug` |

## Running on an Android phone from Android Studio

1. **Start the API** on your laptop (see `backend/README.md`; from IntelliJ or with `docker compose up --build`). Check <http://localhost:8080/actuator/health> shows `UP`.
2. **Prepare the phone:** *Settings → About phone →* tap *Build number* seven times to unlock *Developer options*, then turn on *Developer options → USB debugging*. Connect the phone by USB and accept the "Allow USB debugging?" prompt.
3. **Open the project:** in Android Studio, *File → Open* the `frontend/` folder (with the Flutter and Dart plugins installed). Set the Flutter SDK path under *Settings → Languages & Frameworks → Flutter* if asked.
4. **Generate code** in Android Studio's *Terminal* tab (from `frontend/`): `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs`.
5. **Route the phone to your laptop:** in the same terminal run `adb reverse tcp:8080 tcp:8080`. The phone's `localhost:8080` now reaches the laptop's API over the USB cable, so no Wi-Fi, IP address or firewall setup is needed. If `adb` isn't found, use its full path: `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080`. Repeat this step whenever you reconnect the phone.
6. **Point the app at the API:** *Run → Edit Configurations… →* select `main.dart` → *Additional run args*: `--dart-define=API_BASE_URL=http://localhost:8080`.
7. **Run:** choose your phone in the device dropdown and press *Run* (▶). The first build takes a few minutes.

The Android emulator can skip steps 2 and 5: leave *Additional run args* empty, because the default `http://10.0.2.2:8080` is the emulator's address for your laptop.

## Configuration

Build-time settings use `--dart-define` and are read in `lib/app/environment.dart`:

| Key | Default | Notes |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:8080` | The Android emulator's address for the host machine. Use `http://localhost:8080` with `adb reverse` on a phone, or on the iOS simulator. |

Never put secrets in the app; everything in the binary is public. Debug builds may use plain HTTP only to `10.0.2.2` / `localhost` / `127.0.0.1` (`android/app/src/debug/res/xml/network_security_config.xml`); release builds are HTTPS-only.

## Structure

```
lib/
├── main.dart
├── app/             App widget, router (session-aware redirects, tab shell), environment config
├── core/            errors/ (AppException, user-facing text) · network/ (Dio client, auth interceptor)
│                    storage/ (secure token storage) · models/ (pages, monthly totals)
│                    ui/ (form submission, date field, decimal input, paged lists, dialogs)
│                    utils/ (exact decimals, money/date formatting, UUIDs)
├── design_system/   Tokens, theme and reusable widgets (import design_system.dart)
├── features/
│   ├── auth/        Sign in, create account, session state
│   ├── vehicles/    Garage home, vehicle switcher, add/edit/delete form, odometer history and corrections
│   ├── fuel/        Fuel tab (km/L gauge, spend, history), fill-up form
│   ├── maintenance/ Service tab (upcoming services, filtered history), service form
│   └── expenses/    Expenses tab (spending by period, category, month and vehicle), expense form
│       └── data/ (DTOs, API, repositories) · domain/ (models) · presentation/ (screens, controllers)
└── l10n/            ARB strings (English)
```

Data flows one way: screen → Riverpod controller → repository → API client. Repositories throw only typed `AppException`s; screens turn them into messages with `errorText`.

### Navigation

Signed-in screens sit in a tab shell (`app/app_shell.dart`, go_router `StatefulShellRoute`): a bottom navigation bar on phones and a navigation rail from 600 dp wide. Each tab keeps its own stack and scroll position. Tabs work on the selected vehicle (`SelectedVehicleView` shows the switcher when there are two vehicles). Forms are top-level routes, so they cover the navigation bar, and system Back closes them.

### Numbers and dates

- The API sends decimals as strings. The app keeps them as `FixedDecimal`, whole numbers of cents or millilitres, and never as `double`. `FuelMath` converts between litres, price and amount with the backend's half-up rounding.
- The server calculates every figure (km/L, cost per km, totals). The app only formats them: `formatRupees` gives `Rs. 18,500` (cents only when present), and `formatDate` gives `7 Oct 2026`.
- In the fill-up form, any two of litres, price per litre and amount calculate the third, and the least recently edited field is the calculated one (`FillUpCalculator`).
- New fill-ups, services and expenses carry an app-generated UUID, so a retried request can't save the same record twice.
- Spending totals on the Expenses tab come from the server and include fill-ups (as fuel) and services (as maintenance), so a cost is entered once. Logging, editing or deleting any of the three refreshes them.

### Documents and device access

- Documents are opened from the Garage (the Documents tile) and live on their own screens. Files never pass through the API: the app asks it for a short-lived signed URL, uploads straight to Cloudflare R2 with `StorageClient` (its own Dio, so the access token never leaves for the storage service), then asks the API to confirm. The form keeps one document ID per attempt, so saving again after a failure resumes the same document. See `docs/adr/0011-documents-on-r2.md`.
- `FilePickerService` (`core/services/`) wraps the platform pickers: `image_picker` for the camera and photo library, `file_selector` for PDFs. Photos are re-encoded by `PhotoCompressor` (`flutter_image_compress`) as JPEG with a 1,600 px short side, stepping quality down only if needed to stay under 5 MB; EXIF (location) is dropped. PDFs over 5 MB, or files that aren't really PDFs, are refused before upload.
- Permissions:
  - **iOS:** `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`; iOS asks on first use. The photo picker runs without full metadata, so choosing a photo doesn't need library access on iOS 14+.
  - **Android:** the system camera app and photo picker are used, so no runtime permission is declared. `<queries>` entries let the app find a camera app and a viewer for PDF links.
  - A denied permission shows how to allow it in Settings or use the other source.
- PDFs open in the phone's viewer (`url_launcher`) with a fresh link each time; photos are shown in the app with pinch-to-zoom.

### Reminders and notifications

- Reminders are opened from the Garage (the Reminders tile).
  - Services with a next date or mileage and documents with an expiry date create them on the server.
  - Users add their own (title, due date and/or odometer) and mark them done.
  - The server works out the status (overdue, due soon, upcoming) and the remaining days and kilometres (`docs/adr/0013-reminders-and-notifications.md`).
  - Services, documents, fill-ups and odometer changes refresh them (`refreshReminders`).
- `NotificationController` (`features/notifications/`) decides how reminders reach the user, after they tap *Turn on notifications* on the Reminders screen:
  - **Push (Android):** with Firebase set up, the phone's FCM token is registered with the API, which pushes "due soon" and "due" notifications. Pushes that arrive while the app is open are shown through the same channel.
  - **Local (iOS, or Android without Firebase):** date reminders are scheduled on the device at 9:00 Sri Lanka time on the first due-soon day and on the due day (at most 60, the iOS limit). Mileage reminders show in the app.
  - Signing out unregisters the token on the server, deletes it on the phone and cancels every scheduled notification.
- Tapping a notification opens that vehicle's reminders, also when the tap launched the app.
- Platform code sits behind `LocalNotifications` and `PushMessaging` in `core/services/`. Tests use fakes; nothing calls Firebase.

#### Firebase setup (push on Android)

Push needs `android/app/google-services.json` from the Firebase console (*Project settings → Your apps → Android app `io.github.rimaz17.drivon` → google-services.json*). The file is gitignored. Without it the app still builds (the Gradle plugin only warns, which is how CI builds) and falls back to local notifications. The API needs the matching service account in `FIREBASE_SERVICE_ACCOUNT_BASE64` (see `backend/README.md`).

To try push on a phone:

1. Sign in.
2. Open *Garage → Reminders* and tap *Turn on notifications*.
3. Add your own reminder due today.
4. Start a reminder run: Postman → *Reminders → Run daily reminders (job)*.

Mileage reminders are pushed right after a fill-up or odometer reading reaches them.

iOS push needs an APNs key from the paid Apple Developer Program, so it is not set up in the MVP and no `GoogleService-Info.plist` is needed. To add it later:

1. Register an iOS app with bundle ID `io.github.rimaz17.drivon` in the Firebase console and download `GoogleService-Info.plist`.
2. In Xcode, add the file to the *Runner* target (it is gitignored).
3. Upload the APNs key under *Project settings → Cloud Messaging*.
4. Add the *Push Notifications* and *Background Modes → Remote notifications* capabilities.
5. Allow iOS in `FirebasePushMessaging.supported`.

#### Permissions

- **Android:**
  - `POST_NOTIFICATIONS` is asked for at runtime on Android 13+.
  - `RECEIVE_BOOT_COMPLETED` and the plugin's receivers put scheduled notifications back after a restart.
  - Scheduling is inexact, so no exact-alarm permission is needed.
  - Core library desugaring is on for the plugin.
- **iOS:**
  - Permission is asked for with the system prompt; no `Info.plist` entry is needed for local notifications.
  - `AppDelegate` sets the notification center delegate so notifications show while the app is open.
  - Firebase needs iOS 15, so the deployment target is 15.0.

### Insights and charts

- The Insights tab shows the server's running-cost analytics (`docs/adr/0012-analytics-and-cost-per-km.md`): cost per km for the chosen period split into fuel, maintenance and other, six months of costs, cost per km by month, km/L per full tank over twelve months, the category split and, with two vehicles, a comparison. The app formats these numbers; it never calculates them.
- Charts are design-system components built on `fl_chart` (`design_system/widgets/charts/`). Running-cost parts always use `costSeries` (violet, teal, ochre) in that order, chosen to stay distinguishable with colour-blindness and to keep 3:1 contrast on the dark chart cards. Values show on tap, every chart has a spoken summary, and charts don't animate under reduced motion.
- Fill-ups, services, expenses and odometer changes reload the Insights figures (`refreshInsights`), so the tab never shows stale totals.

### Sessions

- Access and refresh tokens, and the cached profile, live in `flutter_secure_storage` (iOS Keychain, this device only; Android Keystore-backed). Nothing session-related goes into SharedPreferences.
- `AuthInterceptor` adds the access token, refreshes it once on a 401 and retries. Concurrent 401s share one refresh, because the server treats refresh-token reuse as theft.
- At launch the saved session is confirmed with `/users/me`. If the server is unreachable or still waking up, the cached profile keeps the user signed in.
- Signing out revokes the session on the server and clears tokens, the profile and the remembered vehicle selection.

## Design system

Dark theme first, built from the inspiration boards' palette and shapes. Feature code uses only tokens and components from `lib/design_system/`: no literal colors, font sizes, spacing or radii.

- **Colors:** `Theme.of(context).colorScheme` for Material roles, `context.drivonColors` for text levels, status, highlight, hero and chart colors.
- **Type:** Hanken Grotesk (OFL) through `Theme.of(context).textTheme`; numeric styles use tabular figures.
- **Spacing / radii / motion / widths:** `DrivonSpacing` (including `formMaxWidth` and `contentMaxWidth`), `DrivonRadii`, `DrivonMotion`.
- **Layout:** tab bodies use `SheetScrollView`: headline content on the dark canvas, details on a light paper sheet that gets `DrivonTheme.paper()`. Cards on the sheet stay dark; widgets on it read the theme in their own build (see ADR 0010).
- **Components:** `DrivonCard` (surface, highlight, hero), `PillSegmentedControl`, `SectionTitle`, `TagChip`, `StatTile`, `ArcGauge`, `BarList`, `InlineNotice`, `PrimaryButton`, `ContentWidth`, `EmptyState`, `ErrorState`, `LoadingState`. Form and list helpers live in `core/ui/`: `DateFormField` opens the Material calendar on Android and a Cupertino wheel on iOS (optional dates can be cleared), `RecordTile` is a history row, and `PagedListController` with `LoadMoreFooter` pages any list.

A test checks every text/surface pairing in both the dark and paper themes, including the hero gradient, for WCAG AA contrast.

## iOS without a Mac

Development happens on Windows. The `build-ios` CI job runs `flutter build ios --no-codesign` on a macOS runner for every change, so iOS compile errors show up immediately. When adding a feature that needs a permission, add the `ios/Runner/Info.plist` usage description in the same change.

### Running on an iPhone (borrowed Mac, free Apple ID)

1. Install Xcode from the App Store and Flutter 3.44.7 on the Mac; run `flutter doctor` until the iOS toolchain is green, then run `sudo gem install cocoapods` if CocoaPods is missing.
2. Clone the repo, then run `cd frontend && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
3. Open `ios/Runner.xcworkspace` in Xcode. Under *Runner → Signing & Capabilities*, tick *Automatically manage signing* and pick your personal team (add your Apple ID under *Xcode → Settings → Accounts*). If the bundle ID `io.github.rimaz17.drivon` is taken for a personal team, append a suffix locally and don't commit it.
4. Connect the iPhone, trust the Mac, and enable *Developer Mode* on the phone (*Settings → Privacy & Security*).
5. Run `flutter run --release --dart-define=API_BASE_URL=https://<deployed-api>`.
6. On first launch, trust the developer profile on the phone (*Settings → General → VPN & Device Management*). Free-account builds expire after 7 days.
