import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/fuel/presentation/fuel_record_form_screen.dart';
import '../features/fuel/presentation/fuel_screen.dart';
import '../features/vehicles/presentation/garage_screen.dart';
import '../features/vehicles/presentation/vehicle_form_screen.dart';
import 'app_shell.dart';

/// Route paths, kept in one place so screens never hardcode strings.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String createAccount = '/create-account';
  static const String home = '/';
  static const String fuel = '/fuel';
  static const String addVehicle = '/vehicles/new';
  static const String editVehicle = '/vehicles/:vehicleId/edit';
  static const String addFuelRecord = '/vehicles/:vehicleId/fuel/new';
  static const String editFuelRecord = '/vehicles/:vehicleId/fuel/:recordId';

  static String editVehiclePath(String vehicleId) =>
      '/vehicles/$vehicleId/edit';

  static String addFuelRecordPath(String vehicleId) =>
      '/vehicles/$vehicleId/fuel/new';

  static String editFuelRecordPath(String vehicleId, String recordId) =>
      '/vehicles/$vehicleId/fuel/$recordId';

  static const Set<String> signedOutOnly = {signIn, createAccount};
}

/// Where to send the user for [session], or null to stay on [location].
@visibleForTesting
String? redirectForSession(SessionState session, String location) {
  return switch (session) {
    SessionRestoring() =>
      location == AppRoutes.splash ? null : AppRoutes.splash,
    SignedOut() =>
      AppRoutes.signedOutOnly.contains(location) ? null : AppRoutes.signIn,
    SignedIn() =>
      location == AppRoutes.splash || AppRoutes.signedOutOnly.contains(location)
          ? AppRoutes.home
          : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(
    ref.read(sessionControllerProvider),
  );
  ref.listen(sessionControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) =>
        redirectForSession(session.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.createAccount,
        builder: (context, state) => const CreateAccountScreen(),
      ),
      // Tabs. Screens pushed from them (the forms below) are top-level
      // routes, so they cover the navigation bar.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const GarageScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.fuel,
                builder: (context, state) => const FuelScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addVehicle,
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.editVehicle,
        builder: (context, state) =>
            VehicleFormScreen(vehicleId: state.pathParameters['vehicleId']),
      ),
      // Listed before the edit route so "new" is not read as a record ID.
      GoRoute(
        path: AppRoutes.addFuelRecord,
        builder: (context, state) =>
            FuelRecordFormScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      GoRoute(
        path: AppRoutes.editFuelRecord,
        builder: (context, state) => FuelRecordFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          recordId: state.pathParameters['recordId'],
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
