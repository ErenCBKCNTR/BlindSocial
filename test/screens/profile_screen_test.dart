import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:blind_social/screens/profile_screen.dart';

void main() {
  group('ProfileScreen Widget Tests', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser(
        uid: 'test_user_id',
        email: 'test@example.com',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      fakeFirestore = FakeFirebaseFirestore();
    });

    Future<void> pumpProfileScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            auth: mockAuth,
            firestore: fakeFirestore,
          ),
        ),
      );
      // Wait for the async loading to complete
      await tester.pumpAndSettle();
    }

    testWidgets('renders ProfileScreen correctly', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Hesabım'), findsOneWidget);
      expect(find.text('İsim Soyisim'), findsOneWidget);
      expect(find.text('Kullanıcı Adı'), findsWidgets);
      expect(find.text('Doğum Tarihi'), findsOneWidget);
      expect(find.text('Bilgileri Kaydet'), findsOneWidget);
      expect(find.text('Şifre Değiştir'), findsOneWidget);
    });

    testWidgets('loads user data into text fields', (WidgetTester tester) async {
      // Add data to Firestore
      await fakeFirestore.collection('users').doc('test_user_id').set({
        'fullName': 'John Doe',
        'username': 'johndoe',
        'display_preference': 'username',
        'birthDate': DateTime(1990, 5, 15),
      });

      await pumpProfileScreen(tester);

      expect(find.widgetWithText(TextField, 'John Doe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'johndoe'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1990'), findsOneWidget);
    });

    testWidgets('shows validation error when fields are empty on save', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      await tester.tap(find.text('Bilgileri Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Lütfen tüm alanları doldurunuz.'), findsOneWidget);
    });

    testWidgets('updates user profile successfully', (WidgetTester tester) async {
      await fakeFirestore.collection('users').doc('test_user_id').set({
        'fullName': 'Old Name',
        'username': 'oldusername',
        'display_preference': 'username',
        'birthDate': DateTime(1990, 5, 15),
      });

      await pumpProfileScreen(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Old Name'), 'New Name');
      await tester.enterText(find.widgetWithText(TextField, 'oldusername'), 'newusername');

      await tester.tap(find.text('Bilgileri Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Profil güncellendi.'), findsOneWidget);

      final doc = await fakeFirestore.collection('users').doc('test_user_id').get();
      expect(doc.data()!['fullName'], 'New Name');
      expect(doc.data()!['username'], 'newusername');
    });

    testWidgets('shows password fields when toggled', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Yeni Şifre'), findsNothing);
      expect(find.text('Yeni Şifre Tekrar'), findsNothing);

      await tester.tap(find.text('Şifre Değiştir'));
      await tester.pumpAndSettle();

      expect(find.text('Yeni Şifre'), findsOneWidget);
      expect(find.text('Yeni Şifre Tekrar'), findsOneWidget);
    });

    testWidgets('validates matching passwords', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      await tester.tap(find.text('Şifre Değiştir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre').last, 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre Tekrar').last, 'password456');

      await tester.ensureVisible(find.text('Şifreyi Güncelle'));
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pumpAndSettle();

      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    });

    testWidgets('validates password length', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      await tester.tap(find.text('Şifre Değiştir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre').last, 'pass');
      await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre Tekrar').last, 'pass');

      await tester.ensureVisible(find.text('Şifreyi Güncelle'));
      await tester.tap(find.text('Şifreyi Güncelle'));
      await tester.pumpAndSettle();

      expect(find.text('En az 6 karakter olmalı.'), findsOneWidget);
    });
  });
}
