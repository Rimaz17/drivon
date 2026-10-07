import '../../../core/utils/fixed_decimal.dart';
import '../../../l10n/app_localizations.dart';

/// Client-side checks for the fill-up form. They mirror the API's limits so
/// most mistakes are caught before a request; the server stays the authority.
class FuelFormValidators {
  FuelFormValidators(this._l10n);

  static const int maxOdometerKm = 2000000;
  static const int maxStationLength = 100;

  /// Largest values the API accepts, in whole units (millilitres, cents).
  static const int maxLitresUnits = 999999;
  static const int maxPriceUnits = 9999999;
  static const int maxAmountUnits = 999999999;

  final AppLocalizations _l10n;

  static FixedDecimal? parseLitres(String? text) =>
      FixedDecimal.tryParse(text ?? '', scale: FixedDecimal.litresScale);

  static FixedDecimal? parseMoney(String? text) =>
      FixedDecimal.tryParse(text ?? '', scale: FixedDecimal.moneyScale);

  String? litres(String? value) => _positive(
    parseLitres(value),
    value,
    maxUnits: maxLitresUnits,
    required: _l10n.litresRequired,
    invalid: _l10n.litresInvalid,
  );

  String? pricePerLitre(String? value) => _positive(
    parseMoney(value),
    value,
    maxUnits: maxPriceUnits,
    required: _l10n.pricePerLitreRequired,
    invalid: _l10n.pricePerLitreInvalid,
  );

  String? amount(String? value) => _positive(
    parseMoney(value),
    value,
    maxUnits: maxAmountUnits,
    required: _l10n.amountRequired,
    invalid: _l10n.amountInvalid,
  );

  String? odometer(String? value) {
    final km = int.tryParse(value?.trim() ?? '');
    if (km == null) return _l10n.odometerRequired;
    if (km > maxOdometerKm) return _l10n.odometerTooHigh;
    return null;
  }

  String? date(DateTime? value) => value == null ? _l10n.dateRequired : null;

  static String? _positive(
    FixedDecimal? parsed,
    String? raw, {
    required int maxUnits,
    required String required,
    required String invalid,
  }) {
    if (raw == null || raw.trim().isEmpty) return required;
    if (parsed == null || parsed.isZero || parsed.units > maxUnits) {
      return invalid;
    }
    return null;
  }
}
