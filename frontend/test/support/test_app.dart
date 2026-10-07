import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/design_system/design_system.dart';
import 'package:drivon/features/auth/data/auth_api.dart';
import 'package:drivon/features/auth/data/user_cache.dart';
import 'package:drivon/features/fuel/data/fuel_api.dart';
import 'package:drivon/features/vehicles/data/odometer_api.dart';
import 'package:drivon/features/vehicles/data/selected_vehicle_store.dart';
import 'package:drivon/features/vehicles/data/vehicle_api.dart';
import 'package:drivon/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/auth/auth_test_doubles.dart';
import '../features/fuel/fuel_test_doubles.dart';
import '../features/vehicles/odometer_test_doubles.dart';
import '../features/vehicles/vehicle_test_doubles.dart';
import 'fakes.dart';

/// Overrides that keep tests off the network and platform storage.
List<Override> testOverrides({
  FakeAuthApi? authApi,
  InMemoryTokenStore? tokens,
  FakeVehicleApi? vehicleApi,
  InMemorySelectedVehicleStore? selections,
  FakeFuelApi? fuelApi,
  FakeOdometerApi? odometerApi,
  List<Override> extra = const [],
}) => [
  authApiProvider.overrideWithValue(authApi ?? FakeAuthApi()),
  tokenStoreProvider.overrideWithValue(tokens ?? InMemoryTokenStore()),
  userCacheProvider.overrideWithValue(InMemoryUserCache()),
  vehicleApiProvider.overrideWithValue(vehicleApi ?? FakeVehicleApi()),
  selectedVehicleStoreProvider.overrideWithValue(
    selections ?? InMemorySelectedVehicleStore(),
  ),
  fuelApiProvider.overrideWithValue(fuelApi ?? FakeFuelApi()),
  odometerApiProvider.overrideWithValue(odometerApi ?? FakeOdometerApi()),
  ...extra,
];

/// Wraps [child] with the theme and localizations used by the real app.
Widget localizedApp(Widget child) => MaterialApp(
  theme: DrivonTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
