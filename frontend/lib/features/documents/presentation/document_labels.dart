import 'package:flutter/widgets.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/vehicle_document.dart';

extension DocumentTypeLabel on DocumentType {
  String label(AppLocalizations l10n) => switch (this) {
    DocumentType.insurance => l10n.documentTypeInsurance,
    DocumentType.revenueLicence => l10n.documentTypeRevenueLicence,
    DocumentType.registration => l10n.documentTypeRegistration,
    DocumentType.invoice => l10n.documentTypeInvoice,
    DocumentType.receipt => l10n.documentTypeReceipt,
    DocumentType.other => l10n.documentTypeOther,
  };
}

/// Short status for a chip: Expired, Expires soon, Valid; null without an
/// expiry date.
String? expiryStatusLabel(AppLocalizations l10n, ExpiryState state) =>
    switch (state) {
      ExpiryState.expired => l10n.statusExpired,
      ExpiryState.expiringSoon => l10n.statusExpiringSoon,
      ExpiryState.valid => l10n.statusValid,
      ExpiryState.none => null,
    };

/// "Expires in 12 days", "Expires today", "Expired 3 days ago", or the date
/// for documents that are far from expiring.
String expiryDetail(
  BuildContext context,
  AppLocalizations l10n,
  VehicleDocument document,
  DateTime today,
) {
  final expiry = document.expiryDate;
  final days = document.daysUntilExpiry(today);
  if (expiry == null || days == null) return l10n.noExpiryDetail;
  if (days < 0) return l10n.expiredDaysAgo(-days);
  if (days == 0) return l10n.expiresToday;
  if (days <= VehicleDocument.expiringSoonDays) {
    return l10n.expiresInDays(days);
  }
  return l10n.expiresOnDetail(formatDate(context, expiry));
}

/// The headline for the attention card: "Insurance expires in 5 days".
String expiryHeadline(
  AppLocalizations l10n,
  VehicleDocument document,
  DateTime today,
) {
  final name = document.type.label(l10n);
  final days = document.daysUntilExpiry(today) ?? 0;
  if (days < 0) return l10n.documentExpiredHeadline(name);
  if (days == 0) return l10n.documentExpiresTodayHeadline(name);
  return l10n.documentExpiresInHeadline(name, days);
}

/// "820 KB" or "1.4 MB".
String fileSizeLabel(BuildContext context, AppLocalizations l10n, int bytes) {
  const kb = 1024;
  if (bytes < kb * kb) {
    return l10n.fileSizeKb(formatInteger(context, (bytes / kb).ceil()));
  }
  return l10n.fileSizeMb((bytes / (kb * kb)).toStringAsFixed(1));
}
