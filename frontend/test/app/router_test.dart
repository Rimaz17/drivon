import 'package:drivon/app/router.dart';
import 'package:drivon/features/auth/domain/user.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = User(id: '1', name: 'Rimaz', email: 'r@example.com');

  test('holds every route on the splash screen while restoring', () {
    const restoring = SessionRestoring();
    expect(redirectForSession(restoring, AppRoutes.home), AppRoutes.splash);
    expect(redirectForSession(restoring, AppRoutes.splash), isNull);
  });

  test('sends signed-out users to sign-in but lets them switch forms', () {
    const signedOut = SignedOut();
    expect(redirectForSession(signedOut, AppRoutes.home), AppRoutes.signIn);
    expect(redirectForSession(signedOut, AppRoutes.splash), AppRoutes.signIn);
    expect(redirectForSession(signedOut, AppRoutes.createAccount), isNull);
  });

  test('keeps signed-in users out of the sign-in screens', () {
    const signedIn = SignedIn(user);
    expect(redirectForSession(signedIn, AppRoutes.signIn), AppRoutes.home);
    expect(redirectForSession(signedIn, AppRoutes.splash), AppRoutes.home);
    expect(redirectForSession(signedIn, AppRoutes.home), isNull);
  });
}
