import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/submission_status.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../auth/presentation/widgets/auth_fields.dart';
import '../../fuel/presentation/fuel_sync_controller.dart';
import 'account_actions.dart';

/// Asks for the password and deletes the account. A wrong password keeps
/// the dialog open with the error on the field; once the account is gone,
/// the app returns to the sign-in screen, which closes the dialog with it.
Future<void> showDeleteAccountDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const DeleteAccountDialog(),
);

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  String? _passwordError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _passwordError = null);
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionControllerProvider.notifier);
    final clearDeviceData = deviceDataCleaner(ref);
    await submit(
      () => session.deleteAccount(
        _password.text,
        clearDeviceData: clearDeviceData,
      ),
      describe: (error) {
        if (error is ApiProblemException &&
            error.code == ApiErrorCodes.passwordIncorrect) {
          setState(() => _passwordError = l10n.errorPasswordIncorrect);
          return null;
        }
        return errorText(l10n, error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final danger = context.drivonColors.danger;
    final unsynced = ref.watch(
      fuelSyncProvider.select((sync) => sync.pending.length),
    );

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(l10n.deleteAccountDialogTitle),
        scrollable: true,
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteAccountDialogMessage, style: textTheme.bodyLarge),
              if (unsynced > 0) ...[
                const SizedBox(height: DrivonSpacing.sm),
                Text(
                  l10n.deleteAccountPendingFillUps(unsynced),
                  style: textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: DrivonSpacing.xl),
              PasswordField(
                controller: _password,
                enabled: !busy,
                forceErrorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: _delete,
              ),
              if (error != null) ...[
                const SizedBox(height: DrivonSpacing.lg),
                InlineNotice(message: error!),
              ],
              if (slow) ...[
                const SizedBox(height: DrivonSpacing.lg),
                InlineNotice(
                  message: l10n.slowServerNotice,
                  tone: InlineNoticeTone.info,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: danger),
            onPressed: busy ? null : _delete,
            child: busy
                ? Semantics(
                    label: l10n.deletingAccount,
                    excludeSemantics: true,
                    child: SizedBox.square(
                      dimension: DrivonSpacing.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: danger,
                      ),
                    ),
                  )
                : Text(l10n.deleteAccountAction),
          ),
        ],
      ),
    );
  }
}
