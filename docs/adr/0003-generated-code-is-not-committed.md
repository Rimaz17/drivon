# 3. Generated Dart code is not committed

- Status: Accepted
- Date: 2026-10-07

## Context

The app uses code generation: Flutter's `gen-l10n` now, and `freezed` / `json_serializable` (via `build_runner`) from Phase 1. Generated files can either be committed or regenerated on every build, and the project must pick one approach and apply it consistently.

## Decision

Generated Dart code is **not committed**. `.gitignore` excludes `lib/l10n/app_localizations*.dart`, `*.g.dart` and `*.freezed.dart`, and the analyzer excludes the same paths.

- Localizations are produced automatically by `flutter pub get` (`generate: true` in `pubspec.yaml`, settings in `l10n.yaml`).
- When models are added, CI and the documented local workflow run `dart run build_runner build --delete-conflicting-outputs` after `flutter pub get`.

## Consequences

- Reviews and history contain only hand-written code, and generated files can never be stale or hand-edited.
- A fresh checkout must run `flutter pub get` (and `build_runner` once models exist) before analyzing or running; the READMEs and CI do this.
- Builds take slightly longer because of code generation.
