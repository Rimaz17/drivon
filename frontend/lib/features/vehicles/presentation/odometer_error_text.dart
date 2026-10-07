import 'package:flutter/widgets.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/number_format.dart';
import '../../../l10n/app_localizations.dart';

/// Explains an `ODOMETER_OUT_OF_ORDER` error with the range the server
/// allows for the chosen date (its `minKm`/`maxKm` members).
String odometerRangeText(
  BuildContext context,
  AppLocalizations l10n,
  ApiProblemException error,
) {
  final min = error.intProperty('minKm');
  final max = error.intProperty('maxKm');
  String km(int value) => formatInteger(context, value);
  if (min != null && max != null) {
    return l10n.errorOdometerBetween(km(min), km(max));
  }
  if (min != null) return l10n.errorOdometerAtLeast(km(min));
  if (max != null) return l10n.errorOdometerAtMost(km(max));
  return l10n.errorOdometerDecrease;
}
