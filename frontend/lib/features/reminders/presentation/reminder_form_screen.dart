import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/ui/date_form_field.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/ui/text_field_helpers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../domain/reminder.dart';
import 'reminder_controllers.dart';

/// Adds one of the user's own reminders for [vehicleId], or edits one when
/// [reminderId] is given. Service and document reminders change through
/// their records instead.
class ReminderFormScreen extends ConsumerWidget {
  const ReminderFormScreen({
    required this.vehicleId,
    this.reminderId,
    super.key,
  });

  final String vehicleId;
  final String? reminderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = reminderId;
    if (id == null) return _ReminderForm(vehicleId: vehicleId);

    final l10n = AppLocalizations.of(context);
    final key = (vehicleId: vehicleId, reminderId: id);
    return ref
        .watch(reminderProvider(key))
        .when(
          data: (reminder) =>
              _ReminderForm(vehicleId: vehicleId, initial: reminder),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.editReminderTitle)),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) {
            final missing =
                error is ApiProblemException &&
                (error.code == ApiErrorCodes.reminderNotFound ||
                    error.code == ApiErrorCodes.vehicleNotFound);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.editReminderTitle)),
              body: missing
                  ? ErrorState(
                      title: l10n.errorReminderNotFound,
                      message: l10n.recordMissingMessage,
                      retryLabel: l10n.backAction,
                      onRetry: () => context.pop(),
                    )
                  : ErrorState(
                      title: l10n.recordLoadErrorTitle,
                      message: errorText(l10n, error),
                      retryLabel: l10n.retryAction,
                      onRetry: () => ref.invalidate(reminderProvider(key)),
                    ),
            );
          },
        );
  }
}

/// API field names, used to attach server errors to the right input.
abstract final class _Fields {
  static const title = 'title';
  static const dueDate = 'dueDate';
  static const dueKm = 'dueKm';
}

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final Reminder? initial;

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm>
    with SubmissionStatus {
  static const int _maxKm = 2000000;
  static const int _maxTitleLength = 80;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _dueKm = TextEditingController();
  DateTime? _dueDate;
  Map<String, String> _serverErrors = const {};

  /// Kept for every attempt to add this reminder, so a retry after a lost
  /// response can't add it twice.
  late final String _newId = ref
      .read(reminderMutationsProvider)
      .newReminderId();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.title ?? '';
      _dueDate = initial.dueDate;
      _dueKm.text = initial.dueKm?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _dueKm.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  int? get _km => int.tryParse(_dueKm.text.trim());

  int? get _currentKm {
    final vehicles = ref.read(vehiclesControllerProvider).value ?? const [];
    for (final vehicle in vehicles) {
      if (vehicle.id == widget.vehicleId) return vehicle.currentOdometerKm;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = ReminderDraft(
      title: _title.text.trim(),
      dueDate: _dueDate,
      dueKm: _km,
    );
    await submit(() async {
      final mutations = ref.read(reminderMutationsProvider);
      final initial = widget.initial;
      if (initial != null) {
        await mutations.edit(widget.vehicleId, initial.id, draft);
      } else {
        await mutations.add(widget.vehicleId, draft, id: _newId);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? l10n.changesSaved : l10n.reminderAdded,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _markDone(Reminder reminder) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.markReminderDoneTitle,
      message: l10n.markReminderDoneMessage,
      confirmLabel: l10n.markReminderDoneAction,
      cancelLabel: l10n.cancelAction,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref
          .read(reminderMutationsProvider)
          .remove(widget.vehicleId, reminder.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reminderDone)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final minKm = error.intProperty('minKm');
      final fieldError = switch (error.code) {
        ApiErrorCodes.reminderDueMissing => {
          _Fields.dueKm: l10n.reminderDueMissing,
        },
        ApiErrorCodes.reminderDatePast => {
          _Fields.dueDate: l10n.errorReminderDatePast,
        },
        ApiErrorCodes.reminderKmPast when minKm != null => {
          _Fields.dueKm: l10n.errorReminderKmPast(
            formatInteger(context, minKm - 1),
          ),
        },
        ApiErrorCodes.validationFailed when error.fieldErrors.isNotEmpty =>
          error.fieldErrors,
        _ => null,
      };
      if (fieldError != null) {
        setState(() => _serverErrors = fieldError);
        return null;
      }
      switch (error.code) {
        case ApiErrorCodes.reminderLimitReached:
          return l10n.errorReminderLimit;
        case ApiErrorCodes.reminderNotFound:
          return l10n.errorReminderNotFound;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  String? _validateKm(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _dueDate == null ? l10n.reminderDueMissing : null;
    }
    final km = int.tryParse(text);
    if (km == null || km < 1 || km > _maxKm) return l10n.odometerTooHigh;
    final current = _currentKm;
    final unchanged = km == widget.initial?.dueKm;
    if (current != null && km <= current && !unchanged) {
      return l10n.errorReminderKmPast(formatInteger(context, current));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final initial = widget.initial;
    final now = today();
    final initialDate = initial?.dueDate;
    // An overdue reminder keeps its past date while only the title changes.
    final firstDate = initialDate != null && initialDate.isBefore(now)
        ? initialDate
        : now;
    final currentKm = _currentKm;
    const gap = SizedBox(height: DrivonSpacing.lg);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initial != null ? l10n.editReminderTitle : l10n.addReminderTitle,
        ),
      ),
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
                TextFormField(
                  controller: _title,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.reminderTitleLabel,
                    hintText: l10n.reminderTitleHint,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: _maxTitleLength,
                  buildCounter: hiddenCounter,
                  forceErrorText: _serverErrors[_Fields.title],
                  onChanged: (_) => _clearServerError(_Fields.title),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? l10n.reminderTitleRequired
                      : null,
                ),
                const SizedBox(height: DrivonSpacing.xl),
                Text(l10n.reminderDueExplainer, style: textTheme.bodyMedium),
                gap,
                DateFormField(
                  label: l10n.reminderDueDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _dueDate,
                  firstDate: firstDate,
                  lastDate: DateTime(2100),
                  enabled: !busy,
                  errorText: _serverErrors[_Fields.dueDate],
                  clearTooltip: l10n.clearDateTooltip,
                  onCleared: () => setState(() => _dueDate = null),
                  validator: (value) =>
                      value != null &&
                          value != initialDate &&
                          value.isBefore(now)
                      ? l10n.errorReminderDatePast
                      : null,
                  onChanged: (date) {
                    setState(() => _dueDate = date);
                    _clearServerError(_Fields.dueDate);
                    _clearServerError(_Fields.dueKm);
                  },
                ),
                gap,
                TextFormField(
                  controller: _dueKm,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.reminderDueKmLabel,
                    suffixText: l10n.kmUnit,
                    helperText: currentKm == null
                        ? null
                        : l10n.odometerCurrentHelper(
                            formatInteger(context, currentKm),
                          ),
                    errorMaxLines: 3,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  forceErrorText: _serverErrors[_Fields.dueKm],
                  onChanged: (_) => _clearServerError(_Fields.dueKm),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) => _validateKm(l10n, value),
                ),
                const SizedBox(height: DrivonSpacing.xxl),
                if (error != null) ...[InlineNotice(message: error!), gap],
                if (slow) ...[
                  InlineNotice(
                    message: l10n.slowServerNotice,
                    tone: InlineNoticeTone.info,
                  ),
                  gap,
                ],
                PrimaryButton(
                  label: initial != null
                      ? l10n.saveChangesAction
                      : l10n.addReminderAction,
                  busyLabel: l10n.savingReminder,
                  busy: busy,
                  onPressed: _save,
                ),
                if (initial != null) ...[
                  const SizedBox(height: DrivonSpacing.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l10n.markReminderDoneAction),
                    onPressed: busy ? null : () => _markDone(initial),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
