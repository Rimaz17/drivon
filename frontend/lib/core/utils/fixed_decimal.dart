import 'package:flutter/foundation.dart';

/// An exact decimal with a fixed number of fraction digits, stored as a whole
/// number of its smallest unit: Rs. 10,950.50 is 1095050 cents at scale 2,
/// 30.125 L is 30125 millilitres at scale 3.
///
/// The API sends decimals as strings (`"10950.50"`), and money must never pass
/// through `double`, which can't represent most amounts exactly.
@immutable
class FixedDecimal implements Comparable<FixedDecimal> {
  const FixedDecimal(this.units, this.scale)
    : assert(scale >= 0 && scale <= 6, 'Scale must be 0 to 6');

  /// Scale for rupee amounts.
  static const int moneyScale = 2;

  /// Scale for litres, as fuel pumps show them.
  static const int litresScale = 3;

  /// Count of the smallest unit, e.g. cents.
  final int units;

  /// Number of fraction digits.
  final int scale;

  /// Parses a plain decimal such as `"10950.5"` or `"30"`. Grouping commas
  /// are ignored. Returns null for anything else, for negative values, or when
  /// [text] has more fraction digits than [scale].
  static FixedDecimal? tryParse(String text, {required int scale}) {
    final cleaned = text.trim().replaceAll(',', '');
    final match = _pattern.firstMatch(cleaned);
    if (match == null) return null;
    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (fraction.length > scale) return null;
    final digits = '$whole${fraction.padRight(scale, '0')}';
    // 15 digits stay well inside 64-bit integer arithmetic for products.
    if (digits.replaceFirst(RegExp('^0+'), '').length > 15) return null;
    return FixedDecimal(int.parse(digits), scale);
  }

  /// Like [tryParse] but for values from the API, which are always valid.
  static FixedDecimal parse(String text, {required int scale}) {
    final value = tryParse(text, scale: scale);
    if (value == null) {
      throw FormatException('Not a decimal with $scale digits', text);
    }
    return value;
  }

  static final RegExp _pattern = RegExp(r'^(\d+)(?:\.(\d*))?$');

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// [numerator] / [denominator] for non-negative values, rounded half up,
  /// the same rounding the backend uses.
  static int divideHalfUp(int numerator, int denominator) {
    assert(numerator >= 0 && denominator > 0, 'Non-negative values only');
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }

  bool get isZero => units == 0;

  int get wholePart => units ~/ _pow10(scale);

  int get fractionPart => units % _pow10(scale);

  /// The value as the API expects it, e.g. `"10950.50"`.
  String toPlainString() {
    if (scale == 0) return '$units';
    return '$wholePart.${'$fractionPart'.padLeft(scale, '0')}';
  }

  /// Like [toPlainString] without trailing fraction zeros: `"30.5"`, `"30"`.
  String toTrimmedString() {
    final plain = toPlainString();
    if (scale == 0) return plain;
    return plain.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  int compareTo(FixedDecimal other) {
    final common = scale > other.scale ? scale : other.scale;
    return (units * _pow10(common - scale)).compareTo(
      other.units * _pow10(common - other.scale),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FixedDecimal && compareTo(other) == 0;

  @override
  int get hashCode => toTrimmedString().hashCode;

  @override
  String toString() => toPlainString();
}

/// Converters between the three numbers of a fill-up. All use whole units
/// (cents, millilitres) and round half up, so the app shows the same values
/// the backend calculates.
abstract final class FuelMath {
  /// Rupees for [litres] at [pricePerLitre].
  static FixedDecimal amount(FixedDecimal litres, FixedDecimal pricePerLitre) =>
      FixedDecimal(
        FixedDecimal.divideHalfUp(litres.units * pricePerLitre.units, 1000),
        FixedDecimal.moneyScale,
      );

  /// Litres bought for [amount] at [pricePerLitre].
  static FixedDecimal litres(FixedDecimal amount, FixedDecimal pricePerLitre) =>
      FixedDecimal(
        FixedDecimal.divideHalfUp(amount.units * 1000, pricePerLitre.units),
        FixedDecimal.litresScale,
      );

  /// Rupees per litre for [amount] spent on [litres].
  static FixedDecimal pricePerLitre(FixedDecimal amount, FixedDecimal litres) =>
      FixedDecimal(
        FixedDecimal.divideHalfUp(amount.units * 1000, litres.units),
        FixedDecimal.moneyScale,
      );
}
