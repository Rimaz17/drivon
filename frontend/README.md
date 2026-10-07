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
├── app/             App widget, router (session-aware redirects), environment config
├── core/            errors/ (AppException, user-facing text) · network/ (Dio client, auth interceptor)
│                    storage/ (secure token storage) · ui/ (form submission, dialogs) · utils/
├── design_system/   Tokens, theme and reusable widgets (import design_system.dart)
├── features/
│   ├── auth/        Sign in, create account, session state
│   └── vehicles/    Garage home, vehicle switcher, add/edit/delete form
│       └── data/ (DTOs, API, repositories) · domain/ (models) · presentation/ (screens, controllers)
└── l10n/            ARB strings (English)
```

Data flows one way: screen → Riverpod controller → repository → API client. Repositories throw only typed `AppException`s; screens turn them into messages with `errorText`.

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
- **Components:** `DrivonCard` (surface, highlight, hero), `TagChip`, `StatTile`, `ArcGauge`, `InlineNotice`, `PrimaryButton`, `ContentWidth`, `EmptyState`, `ErrorState`, `LoadingState`.

A test checks every text/surface pairing, including the hero gradient, for WCAG AA contrast.

## iOS without a Mac

Development happens on Windows. The `build-ios` CI job runs `flutter build ios --no-codesign` on a macOS runner for every change, so iOS compile errors show up immediately. When adding a feature that needs a permission, add the `ios/Runner/Info.plist` usage description in the same change.

### Running on an iPhone (borrowed Mac, free Apple ID)

1. Install Xcode from the App Store and Flutter 3.44.7 on the Mac; run `flutter doctor` until the iOS toolchain is green, then run `sudo gem install cocoapods` if CocoaPods is missing.
2. Clone the repo, then run `cd frontend && flutter pub get && dart run build_runner build --delete-conflicting-outputs`.
3. Open `ios/Runner.xcworkspace` in Xcode. Under *Runner → Signing & Capabilities*, tick *Automatically manage signing* and pick your personal team (add your Apple ID under *Xcode → Settings → Accounts*). If the bundle ID `io.github.rimaz17.drivon` is taken for a personal team, append a suffix locally and don't commit it.
4. Connect the iPhone, trust the Mac, and enable *Developer Mode* on the phone (*Settings → Privacy & Security*).
5. Run `flutter run --release --dart-define=API_BASE_URL=https://<deployed-api>`.
6. On first launch, trust the developer profile on the phone (*Settings → General → VPN & Device Management*). Free-account builds expire after 7 days.
