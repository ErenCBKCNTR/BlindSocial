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
      if (details.exception.toString().contains('No Firebase App')) {
        caughtNoAppError = true;
      } else {
        originalOnError?.call(details);
      }
    };

    try {
      await tester.pumpWidget(const BlindSocialApp());
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pumpAndSettle();

      // If we caught the "No Firebase App" error, it means the FutureBuilder completed
      // and attempted to render LoginScreen (which uses FirebaseAuth.instance).
      expect(caughtNoAppError, isTrue);
    } finally {
      FlutterError.onError = originalOnError;
    }
  });
}
