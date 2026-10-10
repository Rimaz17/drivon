/// Failures the UI knows how to explain. Repositories throw only these, never
/// transport-level exceptions.
sealed class AppException implements Exception {
  const AppException();
}

/// The device could not reach the API (offline, DNS failure, refused).
final class NoConnectionException extends AppException {
  const NoConnectionException();
}

/// The API took too long to answer, typically while the free server wakes up.
final class ServerTimeoutException extends AppException {
  const ServerTimeoutException();
}

/// The session can no longer be refreshed; the user must sign in again.
final class SessionExpiredException extends AppException {
  const SessionExpiredException();
}

/// The API answered with an RFC 9457 Problem Details error.
final class ApiProblemException extends AppException {
  const ApiProblemException({
    required this.statusCode,
    required this.code,
    this.detail,
    this.fieldErrors = const {},
    this.properties = const {},
  });

  final int statusCode;

  /// Stable machine-readable code, e.g. `VEHICLE_LIMIT_REACHED`.
  final String code;

  /// Server-provided explanation; shown only when no localized text exists.
  final String? detail;

  /// Field name to message, for `VALIDATION_FAILED` responses.
  final Map<String, String> fieldErrors;

  /// Every member of the Problem Details body, including rule-specific ones
  /// such as `minKm` and `maxKm` of `ODOMETER_OUT_OF_ORDER`.
  final Map<String, Object?> properties;

  /// An integer member of the body, or null when absent.
  int? intProperty(String name) {
    final value = properties[name];
    return value is int ? value : null;
  }

  @override
  String toString() => 'ApiProblemException($statusCode $code)';
}

/// Anything else. Logged during development; shown as a generic message.
final class UnexpectedException extends AppException {
  const UnexpectedException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'UnexpectedException($cause)';
}

/// Error codes the app reacts to. Mirrors the backend's `ErrorCode` enum.
abstract final class ApiErrorCodes {
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String emailAlreadyRegistered = 'EMAIL_ALREADY_REGISTERED';
  static const String vehicleNotFound = 'VEHICLE_NOT_FOUND';
  static const String registrationNumberInUse = 'REGISTRATION_NUMBER_IN_USE';
  static const String vehicleLimitReached = 'VEHICLE_LIMIT_REACHED';
  static const String odometerDecrease = 'ODOMETER_DECREASE';
  static const String invalidModelYear = 'INVALID_MODEL_YEAR';
  static const String rateLimited = 'RATE_LIMITED';
  static const String dateInFuture = 'DATE_IN_FUTURE';
  static const String odometerOutOfOrder = 'ODOMETER_OUT_OF_ORDER';
  static const String odometerReadingLocked = 'ODOMETER_READING_LOCKED';
  static const String odometerReadingNotFound = 'ODOMETER_READING_NOT_FOUND';
  static const String fuelRecordNotFound = 'FUEL_RECORD_NOT_FOUND';
  static const String fuelPriceMismatch = 'FUEL_PRICE_MISMATCH';
  static const String maintenanceRecordNotFound =
      'MAINTENANCE_RECORD_NOT_FOUND';
  static const String nextServiceDateInvalid = 'NEXT_SERVICE_DATE_INVALID';
  static const String nextServiceKmInvalid = 'NEXT_SERVICE_KM_INVALID';
  static const String expenseNotFound = 'EXPENSE_NOT_FOUND';
  static const String documentNotFound = 'DOCUMENT_NOT_FOUND';
  static const String documentDatesInvalid = 'DOCUMENT_DATES_INVALID';
  static const String unsupportedFileType = 'UNSUPPORTED_FILE_TYPE';
  static const String fileTooLarge = 'FILE_TOO_LARGE';
  static const String documentLimitReached = 'DOCUMENT_LIMIT_REACHED';
  static const String uploadNotFound = 'UPLOAD_NOT_FOUND';
  static const String uploadMismatch = 'UPLOAD_MISMATCH';
  static const String storageUnavailable = 'STORAGE_UNAVAILABLE';
  static const String reminderNotFound = 'REMINDER_NOT_FOUND';
  static const String reminderDueMissing = 'REMINDER_DUE_MISSING';
  static const String reminderDatePast = 'REMINDER_DATE_PAST';
  static const String reminderKmPast = 'REMINDER_KM_PAST';
  static const String reminderReadOnly = 'REMINDER_READ_ONLY';
  static const String reminderLimitReached = 'REMINDER_LIMIT_REACHED';
  static const String assistantUnavailable = 'ASSISTANT_UNAVAILABLE';
  static const String assistantIncomplete = 'ASSISTANT_INCOMPLETE';
}
