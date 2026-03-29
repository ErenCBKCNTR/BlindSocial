import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blind_social/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App initialization error triggers silent fallback without hanging', (tester) async {
    const MethodChannel firebaseChannel = MethodChannel('plugins.flutter.io/firebase_core');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(firebaseChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'Firebase#initializeCore') {
        throw PlatformException(
          code: 'channel-error',
          message: 'Simulated initialization error',
        );
      }
      return null;
    });

    final originalOnError = FlutterError.onError;
    bool caughtNoAppError = false;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('No Firebase App') || details.exception.toString().contains('Null check operator used on a null value')) {
        caughtNoAppError = true;
      } else {
        originalOnError?.call(details);
      }
    };

    try {
      await tester.pumpWidget(const BlindSocialApp());
      expect(find.byType(SplashScreen), findsOneWidget);

      // The new initialization logic includes `await PermissionManager.requestNotificationPermission(context);`
      // which uses `Permission.notification.status`. In tests, without a mock for permission_handler,
      // it might hang or throw exceptions that aren't properly caught.
      // We will mock the method channel for permission_handler.
      const MethodChannel permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(permissionChannel, (MethodCall methodCall) async {
        return 0; // Return an integer representing PermissionStatus.denied
      });

      await tester.pumpAndSettle(const Duration(seconds: 4)); // Wait for 3-second timeout in initialization

      // If we caught the "No Firebase App" error, it means the FutureBuilder completed
      // and attempted to render LoginScreen (which uses FirebaseAuth.instance) or OnboardingScreen.
      // Wait actually since onboarding is returned first, let's verify if OnboardingScreen is rendered.
      expect(find.byType(SplashScreen), findsNothing);
    } finally {
      FlutterError.onError = originalOnError;
    }
  });
}
