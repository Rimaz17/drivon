import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/insights_screen.dart';
import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/documents/presentation/document_form_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/expenses/presentation/expense_form_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/fuel/presentation/fuel_record_form_screen.dart';
import '../features/fuel/presentation/fuel_screen.dart';
import '../features/maintenance/presentation/maintenance_form_screen.dart';
import '../features/maintenance/presentation/service_screen.dart';
import '../features/reminders/presentation/reminder_form_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/vehicles/presentation/garage_screen.dart';
import '../features/vehicles/presentation/odometer_history_screen.dart';
import '../features/vehicles/presentation/odometer_reading_form_screen.dart';
import '../features/vehicles/presentation/vehicle_form_screen.dart';
import 'app_shell.dart';

/// Route paths, kept in one place so screens never hardcode strings.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String createAccount = '/create-account';
  static const String home = '/';
  static const String fuel = '/fuel';
  static const String service = '/service';
  static const String expenses = '/expenses';
  static const String insights = '/insights';
  static const String addVehicle = '/vehicles/new';
  static const String editVehicle = '/vehicles/:vehicleId/edit';
  static const String addFuelRecord = '/vehicles/:vehicleId/fuel/new';
  static const String editFuelRecord = '/vehicles/:vehicleId/fuel/:recordId';
  static const String addService = '/vehicles/:vehicleId/services/new';
  static const String editService = '/vehicles/:vehicleId/services/:recordId';
  static const String addExpense = '/vehicles/:vehicleId/expenses/new';
  static const String editExpense = '/vehicles/:vehicleId/expenses/:expenseId';
  static const String odometerHistory = '/vehicles/:vehicleId/odometer';
  static const String addOdometerReading = '/vehicles/:vehicleId/odometer/new';
  static const String editOdometerReading =
      '/vehicles/:vehicleId/odometer/:readingId';
  static const String documents = '/vehicles/:vehicleId/documents';
  static const String addDocument = '/vehicles/:vehicleId/documents/new';
  static const String document = '/vehicles/:vehicleId/documents/:documentId';
  static const String editDocument =
      '/vehicles/:vehicleId/documents/:documentId/edit';
  static const String reminders = '/vehicles/:vehicleId/reminders';
  static const String addReminder = '/vehicles/:vehicleId/reminders/new';
  static const String editReminder =
      '/vehicles/:vehicleId/reminders/:reminderId';

  static String editVehiclePath(String vehicleId) =>
      '/vehicles/$vehicleId/edit';

  static String addFuelRecordPath(String vehicleId) =>
      '/vehicles/$vehicleId/fuel/new';

  static String editFuelRecordPath(String vehicleId, String recordId) =>
      '/vehicles/$vehicleId/fuel/$recordId';

  static String addServicePath(String vehicleId) =>
      '/vehicles/$vehicleId/services/new';

  static String editServicePath(String vehicleId, String recordId) =>
      '/vehicles/$vehicleId/services/$recordId';

  static String addExpensePath(String vehicleId) =>
      '/vehicles/$vehicleId/expenses/new';

  static String editExpensePath(String vehicleId, String expenseId) =>
      '/vehicles/$vehicleId/expenses/$expenseId';

  static String odometerHistoryPath(String vehicleId) =>
      '/vehicles/$vehicleId/odometer';

  static String addOdometerReadingPath(String vehicleId) =>
      '/vehicles/$vehicleId/odometer/new';

  static String editOdometerReadingPath(String vehicleId, String readingId) =>
      '/vehicles/$vehicleId/odometer/$readingId';

  static String documentsPath(String vehicleId) =>
      '/vehicles/$vehicleId/documents';

  static String addDocumentPath(String vehicleId) =>
      '/vehicles/$vehicleId/documents/new';

  static String documentPath(String vehicleId, String documentId) =>
      '/vehicles/$vehicleId/documents/$documentId';

  static String editDocumentPath(String vehicleId, String documentId) =>
      '/vehicles/$vehicleId/documents/$documentId/edit';

  static String remindersPath(String vehicleId) =>
      '/vehicles/$vehicleId/reminders';

  static String addReminderPath(String vehicleId) =>
      '/vehicles/$vehicleId/reminders/new';

  static String editReminderPath(String vehicleId, String reminderId) =>
      '/vehicles/$vehicleId/reminders/$reminderId';

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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.service,
                builder: (context, state) => const ServiceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                builder: (context, state) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.insights,
                builder: (context, state) => const InsightsScreen(),
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
      GoRoute(
        path: AppRoutes.addService,
        builder: (context, state) => MaintenanceFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.editService,
        builder: (context, state) => MaintenanceFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          recordId: state.pathParameters['recordId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        builder: (context, state) =>
            ExpenseFormScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      GoRoute(
        path: AppRoutes.editExpense,
        builder: (context, state) => ExpenseFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          expenseId: state.pathParameters['expenseId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.odometerHistory,
        builder: (context, state) => OdometerHistoryScreen(
          vehicleId: state.pathParameters['vehicleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.addOdometerReading,
        builder: (context, state) => OdometerReadingFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.editOdometerReading,
        builder: (context, state) => OdometerReadingFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          readingId: state.pathParameters['readingId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.documents,
        builder: (context, state) =>
            DocumentsScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      // Listed before the document route so "new" is not read as an ID.
      GoRoute(
        path: AppRoutes.addDocument,
        builder: (context, state) =>
            DocumentFormScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      GoRoute(
        path: AppRoutes.document,
        builder: (context, state) => DocumentDetailScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          documentId: state.pathParameters['documentId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.editDocument,
        builder: (context, state) => DocumentFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          documentId: state.pathParameters['documentId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        builder: (context, state) =>
            RemindersScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      // Listed before the edit route so "new" is not read as an ID.
      GoRoute(
        path: AppRoutes.addReminder,
        builder: (context, state) =>
            ReminderFormScreen(vehicleId: state.pathParameters['vehicleId']!),
      ),
      GoRoute(
        path: AppRoutes.editReminder,
        builder: (context, state) => ReminderFormScreen(
          vehicleId: state.pathParameters['vehicleId']!,
          reminderId: state.pathParameters['reminderId'],
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
