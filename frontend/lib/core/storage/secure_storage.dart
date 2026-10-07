import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage shared by everything session-related. On iOS items are
/// readable after the first unlock (for future background work) and never
/// leave this device (no iCloud Keychain sync, no backups).
const FlutterSecureStorage drivonSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
