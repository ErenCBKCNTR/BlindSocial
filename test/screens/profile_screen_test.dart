import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:blind_social/screens/profile_screen.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;

  setUp(() async {
    mockUser = MockUser(
      isAnonymous: false,
      uid: 'test-uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    fakeFirestore = FakeFirebaseFirestore();

    // Populate the mock database with initial user data
    await fakeFirestore.collection('users').doc('test-uid').set({
      'fullName': 'Test User',
      'username': 'testuser123',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(1990, 5, 15)),
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

  testWidgets('renders ProfileScreen and loads initial state correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Hesabım'), findsOneWidget);

    // Verify fields are loaded with mock data
    expect(find.text('Test User'), findsOneWidget); // Full name
    expect(find.text('testuser123'), findsOneWidget); // Username

    // Birthdate fields (15-5-1990)
    expect(find.text('15'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1990'), findsOneWidget);
  });

  testWidgets('toggles password fields visibility when change password button is tapped', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Initially password fields should not be visible
    expect(find.text('Yeni Şifre'), findsNothing);
    expect(find.text('Yeni Şifre Tekrar'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle'), findsNothing);

    // Tap the toggle button
    final toggleButton = find.widgetWithText(TextButton, 'Şifre Değiştir');
    await tester.ensureVisible(toggleButton); // Might be scrolled out
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Now password fields should be visible
    expect(find.text('Yeni Şifre'), findsOneWidget);
    expect(find.text('Yeni Şifre Tekrar'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle'), findsOneWidget);

    // Tap the toggle button again to hide them
    await tester.ensureVisible(toggleButton);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Password fields should be hidden again
    expect(find.text('Yeni Şifre'), findsNothing);
    expect(find.text('Yeni Şifre Tekrar'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle'), findsNothing);
  });

  testWidgets('shows error snackbar when required fields are empty on submit', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle(); // Wait for data to load

    // Clear the full name field
    final fullNameField = find.widgetWithText(TextField, 'Test User');
    await tester.enterText(fullNameField, '');
    await tester.pump();

    // Tap submit button
    final submitButton = find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet');
    await tester.tap(submitButton);
    await tester.pumpAndSettle(); // Wait for snackbar to appear

    // Verify error message
    expect(find.text('Lütfen tüm alanları doldurunuz.'), findsOneWidget);
  });
}
