import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Calendar dates as the API sends them: `2026-10-07`. Records carry dates
/// without a time, so values are local midnights and never converted.
abstract final class ApiDate {
  static final DateFormat _format = DateFormat('yyyy-MM-dd');

  static DateTime parse(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String format(DateTime date) => _format.format(date);

  /// `2026-10`, the API's month format.
  static DateTime parseMonth(String value) => parse('$value-01');
}

/// Today's date, without a time.
DateTime today([DateTime? now]) {
  final moment = now ?? DateTime.now();
  return DateTime(moment.year, moment.month, moment.day);
}

/// `7 Oct 2026`: day first, as dates are written in Sri Lanka.
String formatDate(BuildContext context, DateTime date) =>
    DateFormat('d MMM y', _locale(context)).format(date);

/// `October 2026`.
String formatMonthYear(BuildContext context, DateTime month) =>
    DateFormat('MMMM y', _locale(context)).format(month);

/// `Oct`, for compact month labels.
String formatShortMonth(BuildContext context, DateTime month) =>
    DateFormat('MMM', _locale(context)).format(month);

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();
