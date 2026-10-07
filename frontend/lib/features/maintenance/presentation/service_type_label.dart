import '../../../l10n/app_localizations.dart';
import '../domain/maintenance_record.dart';

extension ServiceTypeLabel on ServiceType {
  String label(AppLocalizations l10n) => switch (this) {
    ServiceType.oilChange => l10n.serviceOilChange,
    ServiceType.generalService => l10n.serviceGeneral,
    ServiceType.tyreRotation => l10n.serviceTyreRotation,
    ServiceType.tyreReplacement => l10n.serviceTyreReplacement,
    ServiceType.brakeService => l10n.serviceBrakes,
    ServiceType.batteryReplacement => l10n.serviceBattery,
    ServiceType.wheelAlignment => l10n.serviceWheelAlignment,
    ServiceType.airConditioning => l10n.serviceAirConditioning,
    ServiceType.other => l10n.serviceOther,
  };
}
