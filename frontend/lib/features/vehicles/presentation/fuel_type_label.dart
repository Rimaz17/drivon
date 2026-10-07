import '../../../l10n/app_localizations.dart';
import '../domain/fuel_type.dart';

extension FuelTypeLabel on FuelType {
  String label(AppLocalizations l10n) => switch (this) {
    FuelType.petrol => l10n.fuelPetrol,
    FuelType.diesel => l10n.fuelDiesel,
    FuelType.hybrid => l10n.fuelHybrid,
  };
}
