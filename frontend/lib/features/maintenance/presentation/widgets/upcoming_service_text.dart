import 'package:flutter/widgets.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/number_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/maintenance_record.dart';
import '../service_type_label.dart';

/// "Oil change due in 12 days", "Brake service is overdue" and so on: the
/// headline of an upcoming service. A date wins over mileage for the
/// headline; [detail] names both.
String upcomingHeadline(
  BuildContext context,
  AppLocalizations l10n,
  UpcomingService upcoming,
) {
  final service = upcoming.serviceType.label(l10n);
  if (upcoming.overdue) return l10n.overdueHeadline(service);
  final days = upcoming.daysRemaining;
  if (days != null) {
    return days == 0
        ? l10n.dueTodayHeadline(service)
        : l10n.dueInDaysHeadline(service, days);
  }
  return l10n.dueInKmHeadline(
    service,
    formatInteger(context, upcoming.kmRemaining ?? 0),
  );
}

/// "Due 7 Apr 2027 or at 51,500 km, whichever comes first".
String upcomingDetail(
  BuildContext context,
  AppLocalizations l10n,
  UpcomingService upcoming,
) {
  final date = upcoming.dueDate;
  final km = upcoming.dueKm;
  if (date != null && km != null) {
    return l10n.dueDetailBoth(
      formatDate(context, date),
      formatInteger(context, km),
    );
  }
  if (date != null) return l10n.dueDetailDate(formatDate(context, date));
  return l10n.dueDetailKm(formatInteger(context, km ?? 0));
}
