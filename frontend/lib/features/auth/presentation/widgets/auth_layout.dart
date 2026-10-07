import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared frame for sign-in and sign-up: wordmark, heading, the form and a
/// footer link to the other screen. Scrolls so the keyboard never hides the
/// submit button, and stays readable on tablets by capping its width.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footerPrompt,
    required this.footerAction,
    required this.onFooterAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final String footerPrompt;
  final String footerAction;
  final VoidCallback? onFooterAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DrivonSpacing.screenGutter,
              vertical: DrivonSpacing.xxxl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DrivonSpacing.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appTitle,
                      style: textTheme.titleLarge?.copyWith(
                        color: context.drivonColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DrivonSpacing.huge),
                  Semantics(
                    header: true,
                    child: Text(title, style: textTheme.displaySmall),
                  ),
                  const SizedBox(height: DrivonSpacing.sm),
                  Text(subtitle, style: textTheme.bodyLarge),
                  const SizedBox(height: DrivonSpacing.xxxl),
                  form,
                  const SizedBox(height: DrivonSpacing.xxl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(footerPrompt, style: textTheme.bodyMedium),
                      TextButton(
                        onPressed: onFooterAction,
                        child: Text(footerAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
