import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:blind_social/screens/register_screen.dart';

// Create a simpler mock to avoid mockito complexities and use anonymous classes/overrides
class FakeFirebaseAuthThrows extends Fake implements FirebaseAuth {
  final FirebaseAuthException exception;

  FakeFirebaseAuthThrows(this.exception);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw exception;
  }
}

void main() {
  group('RegisterScreen Error Handling Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    Future<void> pumpRegisterScreen(WidgetTester tester, FirebaseAuth auth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            auth: auth,
            firestore: fakeFirestore,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillFormAndSubmit(WidgetTester tester) async {
      // Use simpler finding strategy - index of TextFormField
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(7));

      final registerButton = find.byType(ElevatedButton);
      expect(registerButton, findsOneWidget);

      // Enter text
      await tester.enterText(textFields.at(0), 'Test User'); // İsim
      await tester.enterText(textFields.at(1), 'testuser'); // Kullanıcı Adı
      await tester.enterText(textFields.at(2), 'test@example.com'); // E-posta
      await tester.enterText(textFields.at(3), 'password123'); // Şifre
      await tester.enterText(textFields.at(4), '1'); // Gün
      await tester.enterText(textFields.at(5), '1'); // Ay
      await tester.enterText(textFields.at(6), '2000'); // Yıl

      // Close keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Tap register button
      await tester.tap(registerButton);
      await tester.pump(); // Start registration
    }

    testWidgets('shows weak-password error correctly', (WidgetTester tester) async {
      final auth = FakeFirebaseAuthThrows(
        FirebaseAuthException(code: 'weak-password', message: 'The password provided is too weak.'),
      );

      await pumpRegisterScreen(tester, auth);
      await fillFormAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Şifre çok zayıf.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows email-already-in-use error correctly', (WidgetTester tester) async {
      final auth = FakeFirebaseAuthThrows(
        FirebaseAuthException(code: 'email-already-in-use', message: 'The account already exists for that email.'),
      );

      await pumpRegisterScreen(tester, auth);
      await fillFormAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Bu e-posta adresi zaten kullanımda.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows username-already-in-use error correctly (Firestore mock)', (WidgetTester tester) async {
      // Seed Firestore so username check fails
      await fakeFirestore.collection('users').doc('some_id').set({
        'username': 'testuser',
      });

      // Pass a fake auth that will throw an exception if called, just in case
      final auth = FakeFirebaseAuthThrows(
        FirebaseAuthException(code: 'unknown', message: 'Should not reach here'),
      );

      await pumpRegisterScreen(tester, auth);
      await fillFormAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Bu kullanıcı adı zaten alınmış.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows generic error correctly', (WidgetTester tester) async {
      final auth = FakeFirebaseAuthThrows(
        FirebaseAuthException(code: 'unknown', message: 'Some unknown error.'),
      );

      await pumpRegisterScreen(tester, auth);
      await fillFormAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Bir hata oluştu.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
