/// Build-time configuration passed with `--dart-define`.
///
/// Example: `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
/// Secrets never belong here; everything in the app binary is public.
abstract final class Environment {
  /// Base URL of the Drivon API. Defaults to the host machine as seen from the
  /// Android emulator, which is the usual local setup.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
