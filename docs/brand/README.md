# Drivon brand assets

Vector sources for the Drivon logo: a steering-wheel mark whose rim is an open gauge arc, plus the "drivon" wordmark (Hanken Grotesk Medium, converted to outlines).

| File | Use |
|---|---|
| `drivon-app-icon.svg` | App icon master, 1024 × 1024, full-bleed canvas (iOS icon and legacy Android icons) |
| `drivon-notification-silhouette.svg` | Single-color silhouette with heavier strokes for the Android status bar |
| `drivon-lockup-dark.svg` | Mark and wordmark in full color, for dark backgrounds |
| `drivon-lockup-mono-dark.svg` / `drivon-lockup-mono-light.svg` | One-color lockup for dark / light backgrounds |
| `drivon-mark-mono-dark.svg` / `drivon-mark-mono-light.svg` | One-color mark for dark / light backgrounds |

Colors: canvas `#0B0B0D`; rim gradient `#7D56EE` → `#B9A3FF` (0.36) → `#F3C7F8` (0.70) → `#99E7D8`, left to right; spokes `#F4F4F6`; hub `#B9A3FF`.

Where they are used in the app:

- **iOS icon** and **legacy Android icons** (Android 7): PNGs generated from the 1024 icon by `frontend/tool/generate_app_icons.py`.
- **Android adaptive and themed icons** (Android 8+): vector drawables in `frontend/android/app/src/main/res/drawable/ic_launcher_*.xml`, drawn on the same 1024 grid and scaled to 2/3 to sit inside the safe zone.
- **Notification icon**: `frontend/android/app/src/main/res/drawable/ic_stat_drivon.xml`, from the silhouette.
- **Launch animation**: `frontend/lib/design_system/widgets/drivon_logo.dart` draws the same geometry in Flutter.
