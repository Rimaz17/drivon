import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/vehicles/presentation/garage_screen.dart';
import '../features/vehicles/presentation/vehicle_form_screen.dart';

/// Route paths, kept in one place so screens never hardcode strings.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String createAccount = '/create-account';
  static const String home = '/';
  static const String addVehicle = '/vehicles/new';
  static const String editVehicle = '/vehicles/:vehicleId/edit';

  static String editVehiclePath(String vehicleId) =>
      '/vehicles/$vehicleId/edit';

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
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const GarageScreen(),
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
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
