import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blind_social/screens/login_screen.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
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
    await tester.pump(const Duration(seconds: 1)); // allow SnackBar to appear

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Hatalı şifre girdiniz.'), findsOneWidget);
  });
}
