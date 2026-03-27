import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:blind_social/screens/profile_screen.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();

    when(() => mockUser.uid).thenReturn('test_uid');
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    // Create dummy user data
    fakeFirestore.collection('users').doc('test_uid').set({
      'fullName': 'Test User',
      'username': 'testuser',
      'display_preference': 'username',
      'birthDate': DateTime(2000, 1, 1),
    });
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ProfileScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    );
  }

  testWidgets('Şifre güncellendi başarılı mesajı gösterilir', (WidgetTester tester) async {
    when(() => mockUser.updatePassword(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Şifre Değiştir panelini aç
    final toggleButton = find.text('Şifre Değiştir');
    expect(toggleButton, findsOneWidget);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Şifre alanlarını doldur
    final newPasswordField = find.widgetWithText(TextField, 'Yeni Şifre');
    final confirmPasswordField = find.widgetWithText(TextField, 'Yeni Şifre Tekrar');
    expect(newPasswordField, findsOneWidget);
    expect(confirmPasswordField, findsOneWidget);

    await tester.enterText(newPasswordField, '123456');
    await tester.enterText(confirmPasswordField, '123456');
    await tester.pump();

    // Scroll to the update button so it is visible and can be tapped
    final updateButton = find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle');
    await tester.ensureVisible(updateButton);
    expect(updateButton, findsOneWidget);
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    // Başarı mesajının gösterildiğini doğrula
    expect(find.text('Şifre güncellendi.'), findsOneWidget);
    verify(() => mockUser.updatePassword('123456')).called(1);
  });

  testWidgets('FirebaseAuthException durumunda hata mesajı gösterilir', (WidgetTester tester) async {
    // Arrange: updatePassword atıldığında FirebaseAuthException fırlatılmasını sağla
    when(() => mockUser.updatePassword(any())).thenThrow(
      FirebaseAuthException(
        code: 'weak-password',
        message: 'The password provided is too weak.',
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Act: Şifre Değiştir panelini aç
    final toggleButton = find.text('Şifre Değiştir');
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Act: Şifre alanlarını doldur ve butona tıkla
    final newPasswordField = find.widgetWithText(TextField, 'Yeni Şifre');
    final confirmPasswordField = find.widgetWithText(TextField, 'Yeni Şifre Tekrar');
    await tester.enterText(newPasswordField, '123456');
    await tester.enterText(confirmPasswordField, '123456');
    await tester.pump();

    final updateButton = find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle');
    await tester.ensureVisible(updateButton);
    await tester.tap(updateButton);
    await tester.pumpAndSettle(); // SnackBar'ın çıkmasını ve animasyonu bekle

    // Assert: SnackBar içinde hata mesajının olduğunu doğrula
    expect(find.text('The password provided is too weak.'), findsOneWidget);
    verify(() => mockUser.updatePassword('123456')).called(1);
  });

  testWidgets('Şifreler eşleşmediğinde hata mesajı gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final toggleButton = find.text('Şifre Değiştir');
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    final newPasswordField = find.widgetWithText(TextField, 'Yeni Şifre');
    final confirmPasswordField = find.widgetWithText(TextField, 'Yeni Şifre Tekrar');
    await tester.enterText(newPasswordField, '123456');
    await tester.enterText(confirmPasswordField, '654321');
    await tester.pump();

    final updateButton = find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle');
    await tester.ensureVisible(updateButton);
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    verifyNever(() => mockUser.updatePassword(any()));
  });

  testWidgets('Şifre 6 karakterden kısaysa hata mesajı gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final toggleButton = find.text('Şifre Değiştir');
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    final newPasswordField = find.widgetWithText(TextField, 'Yeni Şifre');
    final confirmPasswordField = find.widgetWithText(TextField, 'Yeni Şifre Tekrar');
    await tester.enterText(newPasswordField, '12345');
    await tester.enterText(confirmPasswordField, '12345');
    await tester.pump();

    final updateButton = find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle');
    await tester.ensureVisible(updateButton);
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    expect(find.text('En az 6 karakter olmalı.'), findsOneWidget);
    verifyNever(() => mockUser.updatePassword(any()));
  });
}
