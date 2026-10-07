import '../../../core/utils/fixed_decimal.dart';

/// The three related numbers of a fill-up.
enum FillUpField { litres, pricePerLitre, amount }

/// Keeps litres, price per litre and amount consistent: the user types any
/// two and the third is calculated. The field the user touched least
/// recently is the calculated one, so at the pump (litres and amount on the
/// display) the price per litre is filled in, and with a known price either
/// of the others can be typed.
class FillUpCalculator {
  /// Most recently edited first; the last one is calculated.
  final List<FillUpField> _recent = [
    FillUpField.amount,
    FillUpField.litres,
    FillUpField.pricePerLitre,
  ];

  /// The field whose value is calculated from the other two.
  FillUpField get calculated => _recent.last;

  /// Records that the user typed into [field].
  void edited(FillUpField field) {
    _recent
      ..remove(field)
      ..insert(0, field);
  }

  /// The calculated field's value, or null unless both other values are
  /// present and above zero.
  FixedDecimal? calculate({
    FixedDecimal? litres,
    FixedDecimal? pricePerLitre,
    FixedDecimal? amount,
  }) {
    bool usable(FixedDecimal? value) => value != null && !value.isZero;
    switch (calculated) {
      case FillUpField.litres:
        if (!usable(amount) || !usable(pricePerLitre)) return null;
        return FuelMath.litres(amount!, pricePerLitre!);
      case FillUpField.pricePerLitre:
        if (!usable(amount) || !usable(litres)) return null;
        return FuelMath.pricePerLitre(amount!, litres!);
      case FillUpField.amount:
        if (!usable(litres) || !usable(pricePerLitre)) return null;
        return FuelMath.amount(litres!, pricePerLitre!);
    }
  }
}
