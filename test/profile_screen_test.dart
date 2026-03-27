import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:blind_social/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  testWidgets('ProfileScreen renders and loads data', (WidgetTester tester) async {
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    // Populate fake firestore
    await firestore.collection('users').doc('test_uid').set({
      'fullName': 'Test User',
      'username': 'testuser',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(1990, 1, 1)),
    });

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(auth: auth, firestore: firestore),
    ));

    await tester.pumpAndSettle();

    // Verify initial UI state
    expect(find.text('Hesabım'), findsOneWidget);
    expect(find.text('İsim Soyisim'), findsWidgets);
    expect(find.text('Kullanıcı Adı'), findsWidgets);

    // Check that controllers are populated
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('testuser'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // day and month
    expect(find.text('1990'), findsOneWidget); // year
  });

  testWidgets('ProfileScreen updates profile successfully', (WidgetTester tester) async {
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
    );
    final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    // Populate fake firestore
    await firestore.collection('users').doc('test_uid').set({
      'fullName': 'Test User',
      'username': 'testuser',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(1990, 1, 1)),
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProfileScreen(auth: auth, firestore: firestore)),
    ));

    await tester.pumpAndSettle();

    // Enter new details. Find by widget type instead of semantics label.
    await tester.enterText(find.widgetWithText(TextField, 'İsim Soyisim'), 'New Name');
    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'newuser');

    // Submit
    await tester.tap(find.text('Bilgileri Kaydet'));
    await tester.pumpAndSettle();

    // Check SnackBar
    expect(find.text('Profil güncellendi.'), findsOneWidget);

    // Verify Firestore
    final doc = await firestore.collection('users').doc('test_uid').get();
    expect(doc.data()!['fullName'], 'New Name');
    expect(doc.data()!['username'], 'newuser');
  });

  testWidgets('ProfileScreen validation when fields empty', (WidgetTester tester) async {
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
    );
    final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('users').doc('test_uid').set({
      'fullName': '',
      'username': '',
      'display_preference': 'username',
      'birthDate': null,
    });

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(auth: auth, firestore: firestore),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Bilgileri Kaydet'));
    await tester.pump();

    expect(find.text('Lütfen tüm alanları doldurunuz.'), findsOneWidget);
  });

  testWidgets('ProfileScreen username collision handling', (WidgetTester tester) async {
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
    );
    final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    // Other user has the username
    await firestore.collection('users').doc('other_uid').set({
      'username': 'takenuser',
    });

    await firestore.collection('users').doc('test_uid').set({
      'fullName': 'Test',
      'username': 'myuser',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(2000, 1, 1)),
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProfileScreen(auth: auth, firestore: firestore)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'takenuser');

    await tester.ensureVisible(find.text('Bilgileri Kaydet'));
    await tester.tap(find.text('Bilgileri Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Bu kullanıcı adı zaten alınmış.'), findsOneWidget);
  });

  testWidgets('ProfileScreen shows and validates password fields', (WidgetTester tester) async {
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
    );
    final auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('users').doc('test_uid').set({
      'fullName': 'Test',
      'username': 'myuser',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(2000, 1, 1)),
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProfileScreen(auth: auth, firestore: firestore)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yeni Şifre'), findsNothing);

    // Make sure we scroll down to see the button if it's offscreen
    await tester.ensureVisible(find.text('Şifre Değiştir'));

    await tester.tap(find.text('Şifre Değiştir'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni Şifre'), findsOneWidget);
    expect(find.text('Yeni Şifre Tekrar'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre'), 'pass1');
    await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre Tekrar'), 'pass2');

    await tester.ensureVisible(find.text('Şifreyi Güncelle'));
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);

    // clear the snackbar
    await tester.pump(const Duration(seconds: 4));

    await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre'), 'pass');
    await tester.enterText(find.widgetWithText(TextField, 'Yeni Şifre Tekrar'), 'pass');

    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('En az 6 karakter olmalı.'), findsOneWidget);
  });
}
