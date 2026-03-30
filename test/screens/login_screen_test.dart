import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'package:blind_social/screens/login_screen.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});

    // Mock the permission channel to prevent hangs/errors in Connectivity checks
    const MethodChannel('dev.fluttercommunity.plus/connectivity').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi']; // Mock as connected
      }
      return null;
    });
  });

  testWidgets('LoginScreen shows SnackBar with translated error on FirebaseAuthException', (WidgetTester tester) async {
    final mockAuth = MockFirebaseAuth();
    final fakeFirestore = FakeFirebaseFirestore();

    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.signOut()).thenAnswer((_) async {});
    when(() => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    ));

    await tester.pumpAndSettle();

    final emailField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'ornek@email.com veya kullanıcıadı',
    );
    expect(emailField, findsOneWidget);

    final passwordField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Şifreniz',
    );
    expect(passwordField, findsOneWidget);

    await tester.enterText(emailField, 'test@example.com');
    await tester.enterText(passwordField, 'wrongpassword');

    final loginButton = find.widgetWithText(ElevatedButton, 'Giriş Yap');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await tester.pump();
    await tester.pumpAndSettle(); // allow AlertDialog to appear

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Girmiş olduğunuz bilgilerle eşleşen bir hesap bulunamadı.'), findsOneWidget);
  });
}
