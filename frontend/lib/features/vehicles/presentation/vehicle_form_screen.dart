import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/fuel_type.dart';
import '../domain/vehicle.dart';
import 'vehicle_form_validators.dart';
import 'vehicles_controller.dart';
import 'widgets/fuel_type_field.dart';

/// Adds a vehicle, or edits/deletes one when [vehicleId] is given.
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({this.vehicleId, super.key});

  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

/// API field names, used to attach server errors to the right input.
abstract final class _Fields {
  static const make = 'make';
  static const model = 'model';
  static const year = 'year';
  static const registration = 'registrationNumber';
  static const fuelType = 'fuelType';
  static const odometer = 'currentOdometerKm';
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen>
    with SubmissionStatus {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _registration = TextEditingController();
  final _odometer = TextEditingController();
  FuelType? _fuelType;
  Vehicle? _original;
  Map<String, String> _serverErrors = const {};

  bool get _isEditing => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    final id = widget.vehicleId;
    if (id == null) return;
    final vehicles = ref.read(vehiclesControllerProvider).value ?? const [];
    for (final vehicle in vehicles) {
      if (vehicle.id == id) _original = vehicle;
    }
    final original = _original;
    if (original != null) {
      _make.text = original.make;
      _model.text = original.model;
      _year.text = '${original.year}';
      _registration.text = original.registrationNumber;
      _odometer.text = '${original.currentOdometerKm}';
      _fuelType = original.fuelType;
    }
  }

  @override
  void dispose() {
    for (final controller in [_make, _model, _year, _registration, _odometer]) {
      controller.dispose();
    }
    super.dispose();
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
    final draft = VehicleDraft(
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: int.parse(_year.text.trim()),
      registrationNumber: _registration.text.trim(),
      fuelType: _fuelType!,
      currentOdometerKm: int.parse(_odometer.text.trim()),
    );
    await submit(() async {
      final controller = ref.read(vehiclesControllerProvider.notifier);
      final original = _original;
      if (original != null) {
        await controller.edit(original.id, draft);
      } else {
        final created = await controller.add(draft);
        await ref.read(selectedVehicleIdProvider.notifier).select(created.id);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            original != null ? l10n.vehicleSaved : l10n.vehicleAdded,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _delete(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteVehicleTitle(vehicle.displayName),
      message: l10n.deleteVehicleMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref.read(vehiclesControllerProvider.notifier).remove(vehicle.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleDeleted)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  /// Puts field-specific server errors on their fields; returns the message
  /// for the form-level notice, or null when a field shows it.
  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldError = switch (error.code) {
        ApiErrorCodes.registrationNumberInUse => {
          _Fields.registration: l10n.errorRegistrationInUse,
        },
        ApiErrorCodes.odometerDecrease => {
          _Fields.odometer: l10n.errorOdometerDecrease,
        },
        ApiErrorCodes.invalidModelYear => {
          _Fields.year: l10n.yearRange(DateTime.now().year + 1),
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
        case ApiErrorCodes.vehicleLimitReached:
          return l10n.errorVehicleLimit;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final original = _original;

    if (_isEditing && original == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.editVehicleTitle)),
        body: ErrorState(
          title: l10n.errorVehicleNotFound,
          message: l10n.vehicleMissingMessage,
          retryLabel: l10n.backAction,
          onRetry: () => context.pop(),
        ),
      );
    }

    final minimumKm = original?.currentOdometerKm ?? 0;
    final formattedMinimum = formatInteger(context, minimumKm);
    final validators = VehicleFormValidators(
      l10n,
      currentYear: DateTime.now().year,
      minimumOdometerKm: minimumKm,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          original != null ? l10n.editVehicleTitle : l10n.addVehicleTitle,
        ),
        actions: [
          if (original != null)
            IconButton(
              tooltip: l10n.deleteVehicleTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: busy ? null : () => _delete(original),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
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
                controller: _make,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.makeLabel,
                  hintText: l10n.makeHint,
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: VehicleFormValidators.maxTextLength,
                buildCounter: _noCounter,
                forceErrorText: _serverErrors[_Fields.make],
                onChanged: (_) => _clearServerError(_Fields.make),
                validator: validators.make,
              ),
              const SizedBox(height: DrivonSpacing.lg),
              TextFormField(
                controller: _model,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.modelLabel,
                  hintText: l10n.modelHint,
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: VehicleFormValidators.maxTextLength,
                buildCounter: _noCounter,
                forceErrorText: _serverErrors[_Fields.model],
                onChanged: (_) => _clearServerError(_Fields.model),
                validator: validators.model,
              ),
              const SizedBox(height: DrivonSpacing.lg),
              TextFormField(
                controller: _year,
                enabled: !busy,
                decoration: InputDecoration(labelText: l10n.yearLabel),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                forceErrorText: _serverErrors[_Fields.year],
                onChanged: (_) => _clearServerError(_Fields.year),
                validator: validators.year,
              ),
              const SizedBox(height: DrivonSpacing.lg),
              TextFormField(
                controller: _registration,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.registrationLabel,
                  helperText: l10n.registrationHelper,
                ),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    VehicleFormValidators.maxRegistrationLength,
                  ),
                ],
                forceErrorText: _serverErrors[_Fields.registration],
                onChanged: (_) => _clearServerError(_Fields.registration),
                validator: validators.registration,
              ),
              const SizedBox(height: DrivonSpacing.xl),
              FuelTypeField(
                initialValue: _fuelType,
                enabled: !busy,
                onChanged: (type) {
                  _fuelType = type;
                  _clearServerError(_Fields.fuelType);
                },
                validator: (value) =>
                    _serverErrors[_Fields.fuelType] ??
                    validators.fuelType(value),
              ),
              const SizedBox(height: DrivonSpacing.xl),
              TextFormField(
                controller: _odometer,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.odometerFieldLabel,
                  suffixText: l10n.kmUnit,
                  helperText: original != null
                      ? l10n.odometerHelperMin(formattedMinimum)
                      : null,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                forceErrorText: _serverErrors[_Fields.odometer],
                onChanged: (_) => _clearServerError(_Fields.odometer),
                onFieldSubmitted: (_) => _save(),
                validator: (value) => validators.odometer(
                  value,
                  formattedMinimum: formattedMinimum,
                ),
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
                label: original != null
                    ? l10n.saveChangesAction
                    : l10n.addVehicleAction,
                busyLabel: l10n.savingVehicle,
                busy: busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) => null;
