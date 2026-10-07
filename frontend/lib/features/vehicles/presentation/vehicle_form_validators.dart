import '../../../l10n/app_localizations.dart';
import '../domain/fuel_type.dart';

/// Client-side checks for the vehicle form. They mirror the API's rules so
/// most mistakes are caught before a request; the server stays the authority.
class VehicleFormValidators {
  VehicleFormValidators(
    this._l10n, {
    required this.currentYear,
    this.minimumOdometerKm = 0,
  });

  static const int maxTextLength = 50;
  static const int maxRegistrationLength = 20;
  static const int minYear = 1900;
  static const int maxOdometerKm = 2000000;
  static final RegExp _registrationPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9 -]*$',
  );

  final AppLocalizations _l10n;
  final int currentYear;

  /// When editing, the saved reading; the odometer can't go below it.
  final int minimumOdometerKm;

  int get maxYear => currentYear + 1;

  String? make(String? value) => _required(value, _l10n.makeRequired);

  String? model(String? value) => _required(value, _l10n.modelRequired);

  String? year(String? value) {
    final year = int.tryParse(value?.trim() ?? '');
    if (year == null) return _l10n.yearRequired;
    if (year < minYear || year > maxYear) return _l10n.yearRange(maxYear);
    return null;
  }

  String? registration(String? value) {
    final registration = value?.trim() ?? '';
    if (registration.isEmpty) return _l10n.registrationRequired;
    if (registration.length > maxRegistrationLength ||
        !_registrationPattern.hasMatch(registration)) {
      return _l10n.registrationInvalid;
    }
    return null;
  }

  String? fuelType(FuelType? value) =>
      value == null ? _l10n.fuelTypeRequired : null;

  /// [formattedMinimum] is [minimumOdometerKm] formatted for display.
  String? odometer(String? value, {required String formattedMinimum}) {
    final km = int.tryParse(value?.trim() ?? '');
    if (km == null) return _l10n.odometerRequired;
    if (km > maxOdometerKm) return _l10n.odometerTooHigh;
    if (km < minimumOdometerKm) {
      return _l10n.odometerBelowSaved(formattedMinimum);
    }
    return null;
  }

  static String? _required(String? value, String message) =>
      (value?.trim().isEmpty ?? true) ? message : null;
}
