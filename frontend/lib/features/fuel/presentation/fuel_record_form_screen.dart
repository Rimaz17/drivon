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
import '../../vehicles/presentation/vehicles_controller.dart';
import '../domain/fuel_record.dart';
import 'fill_up_calculator.dart';
import 'fuel_controllers.dart';
import 'fuel_form_validators.dart';

/// Logs a fill-up for [vehicleId], or edits/deletes one when [recordId] is
/// given.
class FuelRecordFormScreen extends ConsumerWidget {
  const FuelRecordFormScreen({
    required this.vehicleId,
    this.recordId,
    super.key,
  });

  final String vehicleId;
  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recordId;
    if (id == null) return _FuelForm(vehicleId: vehicleId);

    final l10n = AppLocalizations.of(context);
    final key = (vehicleId: vehicleId, recordId: id);
    return ref
        .watch(fuelRecordProvider(key))
        .when(
          data: (record) => _FuelForm(vehicleId: vehicleId, initial: record),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.editFillUpTitle)),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) {
            final missing =
                error is ApiProblemException &&
                (error.code == ApiErrorCodes.fuelRecordNotFound ||
                    error.code == ApiErrorCodes.vehicleNotFound);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.editFillUpTitle)),
              body: missing
                  ? ErrorState(
                      title: l10n.errorFuelRecordNotFound,
                      message: l10n.recordMissingMessage,
                      retryLabel: l10n.backAction,
                      onRetry: () => context.pop(),
                    )
                  : ErrorState(
                      title: l10n.recordLoadErrorTitle,
                      message: errorText(l10n, error),
                      retryLabel: l10n.retryAction,
                      onRetry: () => ref.invalidate(fuelRecordProvider(key)),
                    ),
            );
          },
        );
  }
}

/// API field names, used to attach server errors to the right input.
abstract final class _Fields {
  static const date = 'date';
  static const odometer = 'odometerKm';
  static const litres = 'litres';
  static const pricePerLitre = 'pricePerLitre';
  static const amount = 'amount';
  static const station = 'station';
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final FuelRecord? initial;

  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm> with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _litres = TextEditingController();
  final _pricePerLitre = TextEditingController();
  final _amount = TextEditingController();
  final _station = TextEditingController();
  final _calculator = FillUpCalculator();
  late DateTime _date;
  bool _fullTank = true;
  Map<String, String> _serverErrors = const {};

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date ?? today();
    if (initial != null) {
      _odometer.text = '${initial.odometerKm}';
      _litres.text = initial.litres.toTrimmedString();
      _pricePerLitre.text = _moneyText(initial.pricePerLitre);
      _amount.text = _moneyText(initial.amount);
      _station.text = initial.station ?? '';
      _fullTank = initial.fullTank;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _odometer,
      _litres,
      _pricePerLitre,
      _amount,
      _station,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _moneyText(FixedDecimal value) =>
      value.fractionPart == 0 ? '${value.wholePart}' : value.toPlainString();

  TextEditingController _controllerFor(FillUpField field) => switch (field) {
    FillUpField.litres => _litres,
    FillUpField.pricePerLitre => _pricePerLitre,
    FillUpField.amount => _amount,
  };

  static String _apiField(FillUpField field) => switch (field) {
    FillUpField.litres => _Fields.litres,
    FillUpField.pricePerLitre => _Fields.pricePerLitre,
    FillUpField.amount => _Fields.amount,
  };

  /// Fills in the calculated number whenever the other two change.
  void _numberChanged(FillUpField field) {
    _calculator.edited(field);
    final result = _calculator.calculate(
      litres: FuelFormValidators.parseLitres(_litres.text),
      pricePerLitre: FuelFormValidators.parseMoney(_pricePerLitre.text),
      amount: FuelFormValidators.parseMoney(_amount.text),
    );
    final calculated = _calculator.calculated;
    if (result != null) {
      _controllerFor(calculated).text = calculated == FillUpField.litres
          ? result.toTrimmedString()
          : _moneyText(result);
    }
    setState(() {
      _serverErrors = {..._serverErrors}
        ..remove(_apiField(field))
        ..remove(_apiField(calculated));
    });
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = FuelDraft(
      date: _date,
      litres: FuelFormValidators.parseLitres(_litres.text)!,
      amount: FuelFormValidators.parseMoney(_amount.text)!,
      pricePerLitre: FuelFormValidators.parseMoney(_pricePerLitre.text)!,
      odometerKm: int.parse(_odometer.text.trim()),
      fullTank: _fullTank,
      station: _station.text.trim(),
    );
    await submit(() async {
      final mutations = ref.read(fuelMutationsProvider);
      final initial = widget.initial;
      if (initial != null) {
        await mutations.edit(widget.vehicleId, initial.id, draft);
      } else {
        await mutations.add(widget.vehicleId, draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? l10n.changesSaved : l10n.fillUpLogged,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _delete(FuelRecord record) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteFillUpTitle,
      message: l10n.deleteFillUpMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref.read(fuelMutationsProvider).remove(widget.vehicleId, record.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.fillUpDeleted)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  /// Puts field-specific server errors on their fields; returns the message
  /// for the form-level notice, or null when a field shows it.
  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldError = switch (error.code) {
        ApiErrorCodes.odometerOutOfOrder => {
          _Fields.odometer: _odometerRangeText(l10n, error),
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
        case ApiErrorCodes.fuelPriceMismatch:
          return l10n.errorFuelPriceMismatch;
        case ApiErrorCodes.fuelRecordNotFound:
          return l10n.errorFuelRecordNotFound;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  String _odometerRangeText(AppLocalizations l10n, ApiProblemException error) {
    final min = error.intProperty('minKm');
    final max = error.intProperty('maxKm');
    String km(int value) => formatInteger(context, value);
    if (min != null && max != null) {
      return l10n.errorOdometerBetween(km(min), km(max));
    }
    if (min != null) return l10n.errorOdometerAtLeast(km(min));
    if (max != null) return l10n.errorOdometerAtMost(km(max));
    return l10n.errorOdometerDecrease;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validators = FuelFormValidators(l10n);
    final initial = widget.initial;
    final calculated = _calculator.calculated;
    final vehicles = ref.watch(vehiclesControllerProvider).value ?? const [];
    final currentKm = [
      for (final vehicle in vehicles)
        if (vehicle.id == widget.vehicleId) vehicle.currentOdometerKm,
    ].firstOrNull;

    Widget numberField({
      required FillUpField field,
      required TextEditingController controller,
      required String label,
      required String? Function(String?) validator,
      required int maxWhole,
      required int maxFraction,
      String? prefix,
      String? suffix,
    }) {
      final isCalculated = field == calculated;
      final apiField = _apiField(field);
      return TextFormField(
        controller: controller,
        enabled: !busy,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixText: suffix,
          helperText: isCalculated ? l10n.calculatedHelper : null,
        ),
        keyboardType: decimalKeyboard,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          DecimalTextInputFormatter(
            maxWhole: maxWhole,
            maxFraction: maxFraction,
          ),
        ],
        forceErrorText: _serverErrors[apiField],
        onChanged: (_) => _numberChanged(field),
        // The calculated field may stay empty until both inputs are valid;
        // their own errors explain what's missing.
        validator: (value) => isCalculated && (value == null || value.isEmpty)
            ? null
            : validator(value),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editFillUpTitle : l10n.logFillUpTitle),
        actions: [
          if (initial != null)
            IconButton(
              tooltip: l10n.deleteFillUpTooltip,
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
                DateFormField(
                  label: l10n.fillUpDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _date,
                  firstDate: DateTime(1990),
                  lastDate: today(),
                  enabled: !busy,
                  errorText: _serverErrors[_Fields.date],
                  validator: validators.date,
                  onChanged: (date) {
                    _date = date;
                    _clearServerError(_Fields.date);
                  },
                ),
                const SizedBox(height: DrivonSpacing.lg),
                TextFormField(
                  controller: _odometer,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.odometerReadingLabel,
                    suffixText: l10n.kmUnit,
                    helperText: currentKm == null
                        ? null
                        : l10n.odometerCurrentHelper(
                            formatInteger(context, currentKm),
                          ),
                    helperMaxLines: 2,
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
                  validator: validators.odometer,
                ),
                const SizedBox(height: DrivonSpacing.xl),
                Text(
                  l10n.fillUpNumbersHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: DrivonSpacing.md),
                numberField(
                  field: FillUpField.litres,
                  controller: _litres,
                  label: l10n.litresLabel,
                  suffix: l10n.litresUnit,
                  validator: validators.litres,
                  maxWhole: 3,
                  maxFraction: FixedDecimal.litresScale,
                ),
                const SizedBox(height: DrivonSpacing.lg),
                numberField(
                  field: FillUpField.amount,
                  controller: _amount,
                  label: l10n.amountPaidLabel,
                  prefix: l10n.rupeePrefix,
                  validator: validators.amount,
                  maxWhole: 7,
                  maxFraction: FixedDecimal.moneyScale,
                ),
                const SizedBox(height: DrivonSpacing.lg),
                numberField(
                  field: FillUpField.pricePerLitre,
                  controller: _pricePerLitre,
                  label: l10n.pricePerLitreLabel,
                  prefix: l10n.rupeePrefix,
                  validator: validators.pricePerLitre,
                  maxWhole: 5,
                  maxFraction: FixedDecimal.moneyScale,
                ),
                const SizedBox(height: DrivonSpacing.lg),
                SwitchListTile.adaptive(
                  value: _fullTank,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _fullTank = value),
                  title: Text(l10n.fullTankLabel),
                  subtitle: Text(l10n.fullTankHelper),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: DrivonSpacing.md),
                TextFormField(
                  controller: _station,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.stationLabel,
                    hintText: l10n.stationHint,
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  maxLength: FuelFormValidators.maxStationLength,
                  buildCounter: hiddenCounter,
                  forceErrorText: _serverErrors[_Fields.station],
                  onChanged: (_) => _clearServerError(_Fields.station),
                  onFieldSubmitted: (_) => _save(),
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
                  label: _isEditing
                      ? l10n.saveChangesAction
                      : l10n.logFillUpTitle,
                  busyLabel: l10n.savingFillUp,
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
