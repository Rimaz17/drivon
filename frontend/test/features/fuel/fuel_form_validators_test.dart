import 'package:drivon/features/fuel/presentation/fuel_form_validators.dart';
import 'package:drivon/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final validators = FuelFormValidators(l10n);

  test('litres must be above zero and at most 999.999', () {
    expect(validators.litres(''), l10n.litresRequired);
    expect(validators.litres('0'), l10n.litresInvalid);
    expect(validators.litres('0.000'), l10n.litresInvalid);
    expect(validators.litres('1000'), l10n.litresInvalid);
    expect(validators.litres('999.999'), isNull);
    expect(validators.litres('30.5'), isNull);
  });

  test('money must be above zero and within the API limits', () {
    expect(validators.amount(' '), l10n.amountRequired);
    expect(validators.amount('0'), l10n.amountInvalid);
    expect(validators.amount('9999999.99'), isNull);
    expect(validators.amount('10000000'), l10n.amountInvalid);
    expect(validators.pricePerLitre(''), l10n.pricePerLitreRequired);
    expect(validators.pricePerLitre('99999.99'), isNull);
    expect(validators.pricePerLitre('100000'), l10n.pricePerLitreInvalid);
    expect(validators.pricePerLitre('365.5'), isNull);
  });

  test('the odometer is required and capped', () {
    expect(validators.odometer(''), l10n.odometerRequired);
    expect(validators.odometer('2000001'), l10n.odometerTooHigh);
    expect(validators.odometer('46500'), isNull);
  });

  test('a date is required', () {
    expect(validators.date(null), l10n.dateRequired);
    expect(validators.date(DateTime(2026, 10, 7)), isNull);
  });
}
