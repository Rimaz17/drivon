import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Mirrors the backend's password rules: 8 to 72 bytes (BCrypt's limit).
abstract final class PasswordRules {
  static const int minLength = 8;
  static const int maxBytes = 72;
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(AppLocalizations l10n, String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return l10n.emailRequired;
  if (!_emailPattern.hasMatch(email)) return l10n.emailInvalid;
  return null;
}

class EmailField extends StatelessWidget {
  const EmailField({
    required this.controller,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: l10n.emailLabel),
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      autocorrect: false,
      enableSuggestions: false,
      validator: (value) => validateEmail(l10n, value),
    );
  }
}

/// Password input with a show/hide toggle. With [isNewPassword] it applies
/// the sign-up rules and asks password managers to suggest a new password.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.onSubmitted,
    this.isNewPassword = false,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final bool isNewPassword;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      onFieldSubmitted: (_) => widget.onSubmitted(),
      decoration: InputDecoration(
        labelText: l10n.passwordLabel,
        helperText: widget.isNewPassword ? l10n.newPasswordHelper : null,
        suffixIcon: IconButton(
          tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return l10n.passwordRequired;
        if (!widget.isNewPassword) return null;
        if (password.length < PasswordRules.minLength) {
          return l10n.passwordTooShort;
        }
        if (utf8.encode(password).length > PasswordRules.maxBytes) {
          return l10n.passwordTooLong;
        }
        return null;
      },
    );
  }
}
