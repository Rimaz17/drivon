import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/submission_status.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import 'session_controller.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_layout.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    await submit(() async {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      TextInput.finishAutofillContext();
    }, describe: (error) => errorText(l10n, error));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthLayout(
      title: l10n.createAccountTitle,
      subtitle: l10n.createAccountSubtitle,
      footerPrompt: l10n.haveAccountPrompt,
      footerAction: l10n.goToSignIn,
      onFooterAction: busy ? null : () => context.go(AppRoutes.signIn),
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !busy,
                decoration: InputDecoration(labelText: l10n.nameLabel),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 100,
                buildCounter: _noCounter,
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? l10n.nameRequired : null,
              ),
              const SizedBox(height: DrivonSpacing.lg),
              EmailField(controller: _email, enabled: !busy),
              const SizedBox(height: DrivonSpacing.lg),
              PasswordField(
                controller: _password,
                enabled: !busy,
                isNewPassword: true,
                onSubmitted: _createAccount,
              ),
              const SizedBox(height: DrivonSpacing.xxl),
              if (error != null) ...[
                InlineNotice(message: error!),
                const SizedBox(height: DrivonSpacing.lg),
              ],
              if (slow) ...[
                InlineNotice(
                  message: l10n.slowServerNotice,
                  tone: InlineNoticeTone.info,
                ),
                const SizedBox(height: DrivonSpacing.lg),
              ],
              PrimaryButton(
                label: l10n.createAccountAction,
                busyLabel: l10n.creatingAccount,
                busy: busy,
                onPressed: _createAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hides the character counter; the limit only stops runaway input.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) => null;
