import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/ui/date_form_field.dart';
import '../../../core/ui/decimal_input.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/ui/text_field_helpers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/presentation/odometer_error_text.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../domain/maintenance_record.dart';
import 'maintenance_controllers.dart';
import 'service_type_label.dart';

/// Logs a service for [vehicleId], or edits/deletes one when [recordId] is
/// given.
class MaintenanceFormScreen extends ConsumerWidget {
  const MaintenanceFormScreen({
    required this.vehicleId,
    this.recordId,
    super.key,
  });

  final String vehicleId;
  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recordId;
    if (id == null) return _ServiceForm(vehicleId: vehicleId);

    final l10n = AppLocalizations.of(context);
    final key = (vehicleId: vehicleId, recordId: id);
    return ref
        .watch(maintenanceRecordProvider(key))
        .when(
          data: (record) => _ServiceForm(vehicleId: vehicleId, initial: record),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.editServiceTitle)),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) {
            final missing =
                error is ApiProblemException &&
                (error.code == ApiErrorCodes.maintenanceRecordNotFound ||
                    error.code == ApiErrorCodes.vehicleNotFound);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.editServiceTitle)),
              body: missing
                  ? ErrorState(
                      title: l10n.errorServiceNotFound,
                      message: l10n.recordMissingMessage,
                      retryLabel: l10n.backAction,
                      onRetry: () => context.pop(),
                    )
                  : ErrorState(
                      title: l10n.recordLoadErrorTitle,
                      message: errorText(l10n, error),
                      retryLabel: l10n.retryAction,
                      onRetry: () =>
                          ref.invalidate(maintenanceRecordProvider(key)),
                    ),
            );
          },
        );
  }
}

/// API field names, used to attach server errors to the right input.
abstract final class _Fields {
  static const serviceType = 'serviceType';
  static const date = 'date';
  static const odometer = 'odometerKm';
  static const cost = 'cost';
  static const notes = 'notes';
  static const nextDate = 'nextServiceDate';
  static const nextKm = 'nextServiceKm';
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final MaintenanceRecord? initial;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm>
    with SubmissionStatus {
  static const int _maxKm = 2000000;
  static const int _maxCostUnits = 999999999;
  static const int _maxNotesLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  final _nextKm = TextEditingController();
  ServiceType? _type;
  late DateTime _date;
  DateTime? _nextDate;
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date ?? today();
    if (initial != null) {
      _type = initial.serviceType;
      _odometer.text = initial.odometerKm?.toString() ?? '';
      _cost.text = initial.cost.fractionPart == 0
          ? '${initial.cost.wholePart}'
          : initial.cost.toPlainString();
      _notes.text = initial.notes ?? '';
      _nextDate = initial.nextServiceDate;
      _nextKm.text = initial.nextServiceKm?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final controller in [_odometer, _cost, _notes, _nextKm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  static int? _intOrNull(String text) => int.tryParse(text.trim());

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = MaintenanceDraft(
      serviceType: _type!,
      date: _date,
      cost: FixedDecimal.parse(_cost.text, scale: FixedDecimal.moneyScale),
      odometerKm: _intOrNull(_odometer.text),
      notes: _notes.text.trim(),
      nextServiceDate: _nextDate,
      nextServiceKm: _intOrNull(_nextKm.text),
    );
    await submit(() async {
      final mutations = ref.read(maintenanceMutationsProvider);
      final initial = widget.initial;
      if (initial != null) {
        await mutations.edit(widget.vehicleId, initial.id, draft);
      } else {
        await mutations.add(widget.vehicleId, draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? l10n.changesSaved : l10n.serviceLogged,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _delete(MaintenanceRecord record) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteServiceTitle,
      message: l10n.deleteServiceMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref
          .read(maintenanceMutationsProvider)
          .remove(widget.vehicleId, record.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.serviceDeleted)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final minKm = error.intProperty('minKm');
      final fieldError = switch (error.code) {
        ApiErrorCodes.odometerOutOfOrder => {
          _Fields.odometer: odometerRangeText(context, l10n, error),
        },
        ApiErrorCodes.dateInFuture => {_Fields.date: l10n.errorDateInFuture},
        ApiErrorCodes.nextServiceDateInvalid => {
          _Fields.nextDate: l10n.errorNextServiceDate,
        },
        ApiErrorCodes.nextServiceKmInvalid when minKm != null => {
          _Fields.nextKm: l10n.errorNextServiceKm(
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
        case ApiErrorCodes.maintenanceRecordNotFound:
          return l10n.errorServiceNotFound;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  String? _validateOdometer(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final km = int.tryParse(text);
    if (km == null || km > _maxKm) return l10n.odometerTooHigh;
    return null;
  }

  String? _validateCost(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.costRequired;
    final cost = FixedDecimal.tryParse(text, scale: FixedDecimal.moneyScale);
    if (cost == null || cost.units > _maxCostUnits) return l10n.costInvalid;
    return null;
  }

  String? _validateNextKm(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final km = int.tryParse(text);
    if (km == null || km < 1 || km > _maxKm) return l10n.nextServiceKmTooHigh;
    final odometer = _intOrNull(_odometer.text);
    if (odometer != null && km <= odometer) {
      return l10n.errorNextServiceKm(formatInteger(context, odometer));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final initial = widget.initial;
    final vehicles = ref.watch(vehiclesControllerProvider).value ?? const [];
    final currentKm = [
      for (final vehicle in vehicles)
        if (vehicle.id == widget.vehicleId) vehicle.currentOdometerKm,
    ].firstOrNull;
    const gap = SizedBox(height: DrivonSpacing.lg);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initial != null ? l10n.editServiceTitle : l10n.logServiceTitle,
        ),
        actions: [
          if (initial != null)
            IconButton(
              tooltip: l10n.deleteServiceTooltip,
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
                DropdownButtonFormField<ServiceType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.serviceTypeLabel),
                  items: [
                    for (final type in ServiceType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.label(l10n)),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (type) {
                          setState(() => _type = type);
                          _clearServerError(_Fields.serviceType);
                        },
                  forceErrorText: _serverErrors[_Fields.serviceType],
                  validator: (value) =>
                      value == null ? l10n.serviceTypeRequired : null,
                ),
                gap,
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
                    setState(() => _date = date);
                    _clearServerError(_Fields.date);
                  },
                ),
                gap,
                TextFormField(
                  controller: _odometer,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.odometerOptionalLabel,
                    suffixText: l10n.kmUnit,
                    helperText: currentKm == null
                        ? null
                        : l10n.odometerCurrentHelper(
                            formatInteger(context, currentKm),
                          ),
                    errorMaxLines: 3,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  forceErrorText: _serverErrors[_Fields.odometer],
                  onChanged: (_) => _clearServerError(_Fields.odometer),
                  validator: (value) => _validateOdometer(l10n, value),
                ),
                gap,
                TextFormField(
                  controller: _cost,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.costLabel,
                    prefixText: l10n.rupeePrefix,
                    helperText: l10n.costHelper,
                  ),
                  keyboardType: decimalKeyboard,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    DecimalTextInputFormatter(
                      maxWhole: 7,
                      maxFraction: FixedDecimal.moneyScale,
                    ),
                  ],
                  forceErrorText: _serverErrors[_Fields.cost],
                  onChanged: (_) => _clearServerError(_Fields.cost),
                  validator: (value) => _validateCost(l10n, value),
                ),
                gap,
                TextFormField(
                  controller: _notes,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.notesLabel,
                    hintText: l10n.serviceNotesHint,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: _maxNotesLength,
                  buildCounter: hiddenCounter,
                  forceErrorText: _serverErrors[_Fields.notes],
                  onChanged: (_) => _clearServerError(_Fields.notes),
                ),
                const SizedBox(height: DrivonSpacing.xxl),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.nextServiceSectionTitle,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: DrivonSpacing.xs),
                Text(l10n.nextServiceExplainer, style: textTheme.bodyMedium),
                gap,
                DateFormField(
                  // A new key resets the field when the service date moves
                  // past the chosen next date.
                  key: ValueKey(_date),
                  label: l10n.nextServiceDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _nextDate,
                  firstDate: _date.add(const Duration(days: 1)),
                  lastDate: DateTime(2100),
                  enabled: !busy,
                  errorText: _serverErrors[_Fields.nextDate],
                  clearTooltip: l10n.clearDateTooltip,
                  onCleared: () => setState(() => _nextDate = null),
                  validator: (value) => value != null && !value.isAfter(_date)
                      ? l10n.errorNextServiceDate
                      : null,
                  onChanged: (date) {
                    setState(() => _nextDate = date);
                    _clearServerError(_Fields.nextDate);
                  },
                ),
                gap,
                TextFormField(
                  controller: _nextKm,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.nextServiceKmLabel,
                    suffixText: l10n.kmUnit,
                    errorMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  forceErrorText: _serverErrors[_Fields.nextKm],
                  onChanged: (_) => _clearServerError(_Fields.nextKm),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) => _validateNextKm(l10n, value),
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
                      : l10n.logServiceTitle,
                  busyLabel: l10n.savingService,
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
