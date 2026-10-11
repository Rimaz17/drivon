import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/ui/text_field_helpers.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/session_controller.dart';
import '../../auth/presentation/widgets/auth_fields.dart';
import 'account_actions.dart';
import 'delete_account_dialog.dart';

/// The signed-in user's account: edit name and email, sign out, or delete
/// the account. Opened from the Garage app bar.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  /// Matches the server's limit.
  static const int maxNameLength = 100;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

abstract final class _Fields {
  static const String name = 'name';
  static const String email = 'email';
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  Map<String, String> _serverErrors = const {};
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name = TextEditingController(text: user?.name);
    _email = TextEditingController(text: user?.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Whether the fields differ from the saved profile, compared the way the
  /// server stores them.
  bool _changed(User user) =>
      _name.text.trim() != user.name ||
      _email.text.trim().toLowerCase() != user.email;

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !_changed(user)) return;
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await submit(() async {
      await ref
          .read(sessionControllerProvider.notifier)
          .updateProfile(name: _name.text, email: _email.text);
      if (!mounted) return;
      // Shows the details as saved (trimmed, email in lower case).
      final saved = ref.read(currentUserProvider);
      if (saved != null) {
        _name.text = saved.name;
        _email.text = saved.email;
      }
      FocusScope.of(context).unfocus();
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    }, describe: (error) => _describe(l10n, error));
  }

  /// Puts field-specific server errors on their fields; returns the message
  /// for the form-level notice, or null when a field shows it.
  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldErrors = switch (error.code) {
        ApiErrorCodes.emailAlreadyRegistered => {
          _Fields.email: l10n.errorEmailInUse,
        },
        ApiErrorCodes.validationFailed when error.fieldErrors.isNotEmpty =>
          error.fieldErrors,
        _ => null,
      };
      if (fieldErrors != null) {
        setState(() => _serverErrors = fieldErrors);
        return null;
      }
    }
    return errorText(l10n, error);
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await signOut(context, ref);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    // Signed out a moment ago; the router is about to leave this screen.
    if (user == null) return const Scaffold();
    final locked = busy || _signingOut;
    final danger = context.drivonColors.danger;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ContentWidth(
            maxWidth: DrivonSpacing.formMaxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DrivonSpacing.screenGutter,
                DrivonSpacing.lg,
                DrivonSpacing.screenGutter,
                DrivonSpacing.xxxl,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _Identity(user: user),
                const SizedBox(height: DrivonSpacing.huge),
                SectionTitle(l10n.profileDetailsTitle),
                const SizedBox(height: DrivonSpacing.lg),
                TextFormField(
                  controller: _name,
                  enabled: !locked,
                  decoration: InputDecoration(labelText: l10n.nameLabel),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  maxLength: ProfileScreen.maxNameLength,
                  buildCounter: hiddenCounter,
                  forceErrorText: _serverErrors[_Fields.name],
                  onChanged: (_) => _clearServerError(_Fields.name),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.nameRequired
                      : null,
                ),
                const SizedBox(height: DrivonSpacing.lg),
                EmailField(
                  controller: _email,
                  enabled: !locked,
                  textInputAction: TextInputAction.done,
                  forceErrorText: _serverErrors[_Fields.email],
                  onChanged: (_) => _clearServerError(_Fields.email),
                  onSubmitted: _save,
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
                ListenableBuilder(
                  listenable: Listenable.merge([_name, _email]),
                  builder: (context, _) => PrimaryButton(
                    label: l10n.saveChangesAction,
                    busyLabel: l10n.savingProfile,
                    busy: busy,
                    onPressed: _changed(user) && !_signingOut ? _save : null,
                  ),
                ),
                // Sign out stands apart from the form so it doesn't read as
                // one of its actions.
                const SizedBox(height: DrivonSpacing.xxxl),
                const Divider(),
                const SizedBox(height: DrivonSpacing.xxl),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.signOutAction),
                  onPressed: locked ? null : _signOut,
                ),
                const SizedBox(height: DrivonSpacing.xxl),
                const Divider(),
                const SizedBox(height: DrivonSpacing.xxl),
                SectionTitle(l10n.deleteAccountAction),
                const SizedBox(height: DrivonSpacing.sm),
                Text(
                  l10n.deleteAccountExplainer,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: DrivonSpacing.lg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    side: BorderSide(color: danger),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(l10n.deleteAccountAction),
                  onPressed: locked
                      ? null
                      : () => showDeleteAccountDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Who is signed in: an initial on the hero gradient, the name and email.
class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final User user;

  static const double _avatarSize = 64;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.drivonColors;
    final name = user.name.trim();
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();

    return MergeSemantics(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: _avatarSize,
              height: _avatarSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.heroGradient,
                ),
              ),
              child: Text(
                initial,
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onHighlight,
                ),
              ),
            ),
          ),
          const SizedBox(width: DrivonSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: textTheme.titleLarge),
                const SizedBox(height: DrivonSpacing.xxs),
                Text(
                  user.email,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
