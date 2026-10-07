import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/ui/date_form_field.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/odometer_reading.dart';
import 'odometer_controllers.dart';
import 'odometer_error_text.dart';
import 'vehicles_controller.dart';

/// Adds a manual odometer reading, or corrects an initial or manual one
/// (and deletes a manual one) when [readingId] is given.
class OdometerReadingFormScreen extends ConsumerWidget {
  const OdometerReadingFormScreen({
    required this.vehicleId,
    this.readingId,
    super.key,
  });

  final String vehicleId;
  final String? readingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = readingId;
    if (id == null) return _ReadingForm(vehicleId: vehicleId);

    final reading = ref.watch(
      odometerReadingProvider((vehicleId: vehicleId, readingId: id)),
    );
    if (reading == null || !reading.source.canCorrect) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.correctReadingTitle)),
        body: ErrorState(
          title: l10n.errorReadingNotFound,
          message: l10n.recordMissingMessage,
          retryLabel: l10n.backAction,
          onRetry: () => context.pop(),
        ),
      );
    }
    return _ReadingForm(vehicleId: vehicleId, initial: reading);
  }
}

abstract final class _Fields {
  static const date = 'date';
  static const readingKm = 'readingKm';
}

class _ReadingForm extends ConsumerStatefulWidget {
  const _ReadingForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final OdometerReading? initial;

  @override
  ConsumerState<_ReadingForm> createState() => _ReadingFormState();
}

class _ReadingFormState extends ConsumerState<_ReadingForm>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController();
  late DateTime _date;
  Map<String, String> _serverErrors = const {};

  static const int _maxKm = 2000000;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date ?? today();
    if (initial != null) _km.text = '${initial.readingKm}';
  }

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final km = int.parse(_km.text.trim());
    await submit(() async {
      final mutations = ref.read(odometerMutationsProvider);
      final initial = widget.initial;
      if (initial != null) {
        await mutations.correct(widget.vehicleId, initial.id, km, _date);
      } else {
        await mutations.add(widget.vehicleId, km, _date);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? l10n.readingCorrected : l10n.readingAdded,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _delete(OdometerReading reading) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteReadingTitle,
      message: l10n.deleteReadingMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref
          .read(odometerMutationsProvider)
          .remove(widget.vehicleId, reading.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.readingDeleted)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldError = switch (error.code) {
        ApiErrorCodes.odometerOutOfOrder => {
          _Fields.readingKm: odometerRangeText(context, l10n, error),
        },
        ApiErrorCodes.dateInFuture => {_Fields.date: l10n.errorDateInFuture},
        ApiErrorCodes.validationFailed when error.fieldErrors.isNotEmpty =>
          error.fieldErrors,
        _ => null,
      };
      if (fieldError != null) {
        setState(() => _serverErrors = fieldError);
        return null;
      }
      switch (error.code) {
        case ApiErrorCodes.odometerReadingLocked:
          return l10n.errorReadingLocked;
        case ApiErrorCodes.odometerReadingNotFound:
          return l10n.errorReadingNotFound;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = widget.initial;
    final vehicles = ref.watch(vehiclesControllerProvider).value ?? const [];
    final currentKm = [
      for (final vehicle in vehicles)
        if (vehicle.id == widget.vehicleId) vehicle.currentOdometerKm,
    ].firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initial != null ? l10n.correctReadingTitle : l10n.addReadingTitle,
        ),
        actions: [
          if (initial != null && initial.source.canDelete)
            IconButton(
              tooltip: l10n.deleteReadingTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: busy ? null : () => _delete(initial),
            ),
        ],
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
                if (initial != null) ...[
                  InlineNotice(
                    message: l10n.correctReadingExplainer,
                    tone: InlineNoticeTone.info,
                  ),
                  const SizedBox(height: DrivonSpacing.xl),
                ],
                DateFormField(
                  label: l10n.fillUpDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _date,
                  firstDate: DateTime(1990),
                  lastDate: today(),
                  enabled: !busy,
                  errorText: _serverErrors[_Fields.date],
                  validator: (value) =>
                      value == null ? l10n.dateRequired : null,
                  onChanged: (date) {
                    _date = date;
                    _clearServerError(_Fields.date);
                  },
                ),
                const SizedBox(height: DrivonSpacing.lg),
                TextFormField(
                  controller: _km,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.odometerReadingLabel,
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
                  forceErrorText: _serverErrors[_Fields.readingKm],
                  onChanged: (_) => _clearServerError(_Fields.readingKm),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) {
                    final km = int.tryParse(value?.trim() ?? '');
                    if (km == null) return l10n.odometerRequired;
                    if (km > _maxKm) return l10n.odometerTooHigh;
                    return null;
                  },
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
                  label: l10n.saveReadingAction,
                  busyLabel: l10n.savingReading,
                  busy: busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
