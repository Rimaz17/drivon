import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared frame for sign-in and sign-up: the logo, heading, the form and a
/// footer link to the other screen.
///
/// The logo sits centred in the upper part of the screen and the form in the
/// lower part, within easy reach of the thumb. When they don't fit (keyboard
/// open, large text, landscape) the screen scrolls instead, so the keyboard
/// never hides the submit button. The width is capped for tablets.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footerPrompt,
    required this.footerAction,
    required this.onFooterAction,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final String footerPrompt;
  final String footerAction;
  final VoidCallback? onFooterAction;

  /// Style of [title]; `displaySmall` unless given, e.g. a smaller style for
  /// a longer title.
  final TextStyle? titleStyle;

  static const double _logoMarkWidth = 104;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: DrivonSpacing.screenGutter,
              vertical: DrivonSpacing.xxl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                // At least a screen tall, so the spare height can be shared
                // out around the logo and the form.
                constraints: BoxConstraints(
                  maxWidth: DrivonSpacing.formMaxWidth,
                  minHeight: math.max(
                    0,
                    viewport.maxHeight - 2 * DrivonSpacing.xxl,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: l10n.appTitle,
                      image: true,
                      child: const Center(
                        child: DrivonLogo.lockup(markWidth: _logoMarkWidth),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Keeps the logo clear of the heading when space is
                        // short (small phones, keyboard open).
                        const SizedBox(height: DrivonSpacing.xxxl),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: titleStyle ?? textTheme.displaySmall,
                          ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
