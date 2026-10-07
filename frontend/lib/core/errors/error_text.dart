import '../../l10n/app_localizations.dart';
import 'app_exception.dart';

/// A user-facing sentence for [error]: what happened and what to do next.
///
/// Feature screens handle their own field-level codes first and fall back
/// to this for everything else.
String errorText(AppLocalizations l10n, Object error) => switch (error) {
  NoConnectionException() => l10n.errorNoConnection,
  ServerTimeoutException() => l10n.errorServerTimeout,
  SessionExpiredException() => l10n.sessionExpiredNotice,
  ApiProblemException(:final code) => switch (code) {
    ApiErrorCodes.invalidCredentials => l10n.errorInvalidCredentials,
    ApiErrorCodes.emailAlreadyRegistered => l10n.errorEmailTaken,
    ApiErrorCodes.rateLimited => l10n.errorRateLimited,
    ApiErrorCodes.validationFailed => l10n.errorValidation,
    _ => l10n.errorGeneric,
  },
  _ => l10n.errorGeneric,
};
