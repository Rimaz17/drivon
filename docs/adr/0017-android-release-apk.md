# 17. Android release APK

- Status: Accepted
- Date: 2026-10-12

## Context

The MVP isn't published to Google Play (out of scope), but people looking at the project should be able to install the Android app. A release build needs three things the debug build doesn't: a stable signing key (Android only installs an update signed with the same key as the installed app), the deployed API's HTTPS address (release builds refuse plain HTTP), and a version code that goes up with every build. The key and its passwords must never reach git, and the build must be reproducible without the developer's laptop.

## Decision

- **Signing:** `android/app/build.gradle.kts` reads the release key from `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). The file and every `*.jks` / `*.keystore` are gitignored. Without the file, release builds fall back to the debug key, so `flutter run --release` still works on any machine; such builds are never shared.
- **Where the APK is built:** the `Android release` workflow (`.github/workflows/android-release.yml`) on GitHub Actions.
  - A `vMAJOR.MINOR.PATCH` tag builds the APK and attaches it, with a SHA-256 checksum file, to a GitHub Release for that tag (release notes generated from the merged pull requests).
  - A manual run builds the same APK and keeps it as a workflow artifact only, for testing before tagging.
- **Inputs:** repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `DRIVON_API_URL` (the same secret the reminders workflow uses). `GOOGLE_SERVICES_JSON_BASE64` is optional and turns on push notifications. The workflow stops before building if a required secret is missing or the API URL isn't `https://`, and fails if the finished APK is signed with a debug key.
- **Versions:** the tag gives the version name (`v1.0.0` → `1.0.0`); the workflow run number is the version code, so each build installs over the previous one.
- **Checks:** the workflow runs `flutter analyze` and `flutter test` before building, even though the tagged commit already passed Frontend CI.
- **One universal APK** rather than one per CPU architecture: about 60 MB, but there is one file to download and nothing to choose.

## Consequences

- The release key lives only in the developer's own backup and in GitHub secrets. Losing it means a new key, and users must uninstall the old app before installing a new release (their data is on the server, so only fill-ups still waiting to sync would be lost).
- Release builds need the API deployed first, since the URL is compiled into the app.
- Builds from the debug-key fallback can't update a release install, and vice versa.
- Moving to Google Play later would mean an app bundle (`flutter build appbundle`) and Play App Signing; the upload key can be this same key.
