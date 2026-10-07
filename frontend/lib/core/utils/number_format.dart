import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'fixed_decimal.dart';

/// Formats a whole number with the locale's grouping, e.g. 45,000.
String formatInteger(BuildContext context, int value) =>
    NumberFormat.decimalPattern(_locale(context)).format(value);

/// A rupee amount as Sri Lankans write it: `Rs. 18,500`, or `Rs. 3,694.90`
/// when there are cents. [showCents] always shows them, e.g. for prices.
String formatRupees(
  BuildContext context,
  FixedDecimal amount, {
  bool showCents = false,
}) {
  final number = showCents || amount.fractionPart != 0
      ? formatDecimal(context, amount, trimZeros: false)
      : formatInteger(context, amount.wholePart);
  return 'Rs. $number';
}

/// [value] with grouping. Fraction digits are kept as stored, or with
/// trailing zeros removed when [trimZeros] is set: `30.5`, `1,250`.
String formatDecimal(
  BuildContext context,
  FixedDecimal value, {
  bool trimZeros = true,
}) {
  final whole = formatInteger(context, value.wholePart);
  if (value.scale == 0) return whole;
  var fraction = '${value.fractionPart}'.padLeft(value.scale, '0');
  if (trimZeros) fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();
