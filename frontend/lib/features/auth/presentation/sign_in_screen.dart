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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    await submit(() async {
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
    }, describe: (error) => errorText(l10n, error));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final expired = session is SignedOut && session.sessionExpired;

    return AuthLayout(
      title: l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      footerPrompt: l10n.noAccountPrompt,
      footerAction: l10n.goToCreateAccount,
      onFooterAction: busy ? null : () => context.go(AppRoutes.createAccount),
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired && error == null) ...[
                InlineNotice(
                  message: l10n.sessionExpiredNotice,
                  tone: InlineNoticeTone.info,
                ),
                const SizedBox(height: DrivonSpacing.lg),
              ],
              EmailField(controller: _email, enabled: !busy),
              const SizedBox(height: DrivonSpacing.lg),
              PasswordField(
                controller: _password,
                enabled: !busy,
                onSubmitted: _signIn,
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
                label: l10n.signInAction,
                busyLabel: l10n.signingIn,
                busy: busy,
                onPressed: _signIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
