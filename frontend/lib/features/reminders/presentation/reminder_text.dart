import 'package:flutter/widgets.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../documents/presentation/document_labels.dart';
import '../../maintenance/presentation/service_type_label.dart';
import '../domain/reminder.dart';

/// What is due: the service or document type, or the user's own title.
String reminderName(AppLocalizations l10n, Reminder reminder) =>
    switch (reminder.source) {
      ReminderSource.manual => reminder.title ?? '',
      ReminderSource.service =>
        reminder.serviceType?.label(l10n) ?? l10n.serviceOther,
      ReminderSource.document =>
        reminder.documentType?.label(l10n) ?? l10n.documentTypeOther,
    };

String reminderStatusLabel(AppLocalizations l10n, ReminderStatus status) =>
    switch (status) {
      ReminderStatus.overdue => l10n.reminderStatusOverdue,
      ReminderStatus.dueSoon => l10n.reminderStatusDueSoon,
      ReminderStatus.upcoming => l10n.reminderStatusUpcoming,
    };

/// True when a reminder with a date and a mileage counts as due soon because
/// of its mileage, while the date is still further off.
bool _mileageLeads(Reminder reminder, DateTime today) {
  if (reminder.dueKm == null) return false;
  final remindFrom = reminder.remindFrom;
  if (reminder.dueDate == null || remindFrom == null) return true;
  return reminder.status != ReminderStatus.upcoming &&
      today.isBefore(remindFrom);
}

/// "Oil change due in 5 days", "Insurance expires today", "Emission test is
/// overdue": the reminder in one line, by whichever of date and mileage
/// matters most right now.
String reminderHeadline(
  BuildContext context,
  AppLocalizations l10n,
  Reminder reminder,
  DateTime today,
) {
  final name = reminderName(l10n, reminder);
  final days = reminder.daysRemaining;
  if (reminder.source == ReminderSource.document) {
    final remaining = days ?? 0;
    if (remaining < 0) return l10n.documentExpiredHeadline(name);
    if (remaining == 0) return l10n.documentExpiresTodayHeadline(name);
    return l10n.documentExpiresInHeadline(name, remaining);
  }
  if (reminder.status == ReminderStatus.overdue) {
    return l10n.overdueHeadline(name);
  }
  final km = reminder.kmRemaining;
  if (km != null && (days == null || _mileageLeads(reminder, today))) {
    return km <= 0
        ? l10n.reminderDueNowHeadline(name)
        : l10n.dueInKmHeadline(name, formatInteger(context, km));
  }
  if (days == 0) return l10n.dueTodayHeadline(name);
  return l10n.dueInDaysHeadline(name, days ?? 0);
}

/// "Due 7 Apr 2027 or at 51,500 km, whichever comes first", or the expiry
/// date of a document.
String reminderDetail(
  BuildContext context,
  AppLocalizations l10n,
  Reminder reminder,
) {
  final date = reminder.dueDate;
  final km = reminder.dueKm;
  if (reminder.source == ReminderSource.document && date != null) {
    final formatted = formatDate(context, date);
    return reminder.status == ReminderStatus.overdue
        ? l10n.expiredOnDetail(formatted)
        : l10n.expiresOnDetail(formatted);
  }
  if (date != null && km != null) {
    return l10n.dueDetailBoth(
      formatDate(context, date),
      formatInteger(context, km),
    );
  }
  if (date != null) return l10n.dueDetailDate(formatDate(context, date));
  return l10n.dueDetailKm(formatInteger(context, km ?? 0));
}
