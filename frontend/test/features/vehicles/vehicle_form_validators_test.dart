import 'package:drivon/features/vehicles/domain/fuel_type.dart';
import 'package:drivon/features/vehicles/presentation/vehicle_form_validators.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  VehicleFormValidators validators({int minimumKm = 0}) =>
      VehicleFormValidators(
        l10n,
        currentYear: 2026,
        minimumOdometerKm: minimumKm,
      );

  test('requires make and model', () {
    expect(validators().make('  '), l10n.makeRequired);
    expect(validators().model(null), l10n.modelRequired);
    expect(validators().make('Toyota'), isNull);
  });

  test('accepts model years from 1900 up to next year', () {
    final v = validators();
    expect(v.year(''), l10n.yearRequired);
    expect(v.year('1899'), l10n.yearRange(2027));
    expect(v.year('1900'), isNull);
    expect(v.year('2027'), isNull);
    expect(v.year('2028'), l10n.yearRange(2027));
  });

  test('checks registration characters and length', () {
    final v = validators();
    expect(v.registration(''), l10n.registrationRequired);
    expect(v.registration('WP CAB-1234'), isNull);
    expect(v.registration('CAB/1234'), l10n.registrationInvalid);
    expect(v.registration('-CAB'), l10n.registrationInvalid);
    expect(v.registration('A' * 21), l10n.registrationInvalid);
  });

  test('requires a fuel type', () {
    expect(validators().fuelType(null), l10n.fuelTypeRequired);
    expect(validators().fuelType(FuelType.diesel), isNull);
  });

  test('keeps the odometer within range and never below the saved reading', () {
    final v = validators(minimumKm: 45000);
    expect(v.odometer('', formattedMinimum: '45,000'), l10n.odometerRequired);
    expect(
      v.odometer('44999', formattedMinimum: '45,000'),
      l10n.odometerBelowSaved('45,000'),
    );
    expect(v.odometer('45000', formattedMinimum: '45,000'), isNull);
    expect(
      v.odometer('2000001', formattedMinimum: '45,000'),
      l10n.odometerTooHigh,
    );
  });
}
