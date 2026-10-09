import 'package:freezed_annotation/freezed_annotation.dart';

part 'vehicle_document.freezed.dart';

/// Kinds of vehicle documents. Wire values match the backend's enum.
enum DocumentType {
  insurance('INSURANCE'),
  revenueLicence('REVENUE_LICENCE'),
  registration('REGISTRATION'),
  invoice('INVOICE'),
  receipt('RECEIPT'),
  other('OTHER');

  const DocumentType(this.wireValue);

  final String wireValue;

  static DocumentType fromWire(String value) => values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => throw FormatException('Unknown document type: $value'),
  );
}

/// How a document's expiry date stands today.
enum ExpiryState {
  /// The document has no expiry date (e.g. a receipt).
  none,
  valid,

  /// Expires within [VehicleDocument.expiringSoonDays] days.
  expiringSoon,
  expired,
}

/// File formats the API accepts. Photos are compressed to JPEG first.
abstract final class DocumentContentTypes {
  static const String jpeg = 'image/jpeg';
  static const String png = 'image/png';
  static const String pdf = 'application/pdf';

  /// Largest file the API accepts: 5 MB.
  static const int maxBytes = 5 * 1024 * 1024;
}

/// A stored vehicle document: details plus metadata of its file in private
/// storage. The file itself is opened through a short-lived link.
@freezed
abstract class VehicleDocument with _$VehicleDocument {
  const factory VehicleDocument({
    required String id,
    required String vehicleId,
    required DocumentType type,
    required String contentType,
    required int sizeBytes,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? notes,
  }) = _VehicleDocument;

  const VehicleDocument._();

  /// Matches the API's default window for "expiring soon".
  static const int expiringSoonDays = 30;

  bool get isPdf => contentType == DocumentContentTypes.pdf;

  /// Whole days from [today] to the expiry date; negative once expired.
  int? daysUntilExpiry(DateTime today) {
    final expiry = expiryDate;
    if (expiry == null) return null;
    // Calendar dates: compare in UTC so daylight saving can't shift a day.
    return DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  /// A document is valid through its expiry date and expired the day after.
  ExpiryState expiryState(DateTime today) {
    final days = daysUntilExpiry(today);
    if (days == null) return ExpiryState.none;
    if (days < 0) return ExpiryState.expired;
    if (days <= expiringSoonDays) return ExpiryState.expiringSoon;
    return ExpiryState.valid;
  }

  DocumentDraft toDraft() => DocumentDraft(
    type: type,
    issueDate: issueDate,
    expiryDate: expiryDate,
    notes: notes,
  );
}

/// The editable details of a document; its file is set once, on upload.
@freezed
abstract class DocumentDraft with _$DocumentDraft {
  const factory DocumentDraft({
    required DocumentType type,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? notes,
  }) = _DocumentDraft;
}
