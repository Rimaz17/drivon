import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats a whole number with the locale's grouping, e.g. 45,000.
String formatInteger(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);
