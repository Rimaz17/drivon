import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which vehicle the user last looked at. Not sensitive (an ID),
/// so plain preferences are fine; entries are scoped to the user.
abstract interface class SelectedVehicleStore {
  Future<String?> read(String userId);
  Future<void> write(String userId, String vehicleId);
  Future<void> clear();
}

class PreferencesSelectedVehicleStore implements SelectedVehicleStore {
  PreferencesSelectedVehicleStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _prefix = 'drivon.selectedVehicle.';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String userId) => _preferences.getString(_key(userId));

  @override
  Future<void> write(String userId, String vehicleId) =>
      _preferences.setString(_key(userId), vehicleId);

  /// Forgets the selection for every user on this device (sign-out).
  @override
  Future<void> clear() async {
    final keys = await _preferences.getKeys();
    await _preferences.clear(
      allowList: keys.where((key) => key.startsWith(_prefix)).toSet(),
    );
  }

  static String _key(String userId) => '$_prefix$userId';
}

final selectedVehicleStoreProvider = Provider<SelectedVehicleStore>(
  (ref) => PreferencesSelectedVehicleStore(),
);
