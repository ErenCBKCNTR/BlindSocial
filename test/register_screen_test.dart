import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:blind_social/screens/register_screen.dart';
import 'register_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  UserCredential,
  User,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    when(mockUser.uid).thenReturn('test_uid');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUserCredential.user).thenReturn(mockUser);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: RegisterScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
      routes: {
        '/chat_rooms': (context) => const Scaffold(body: Text('Chat Rooms')),
      },
    );
  }

  Future<void> fillForm(WidgetTester tester) async {
    // Find TextFields without Semantics since we use InputDecoration hint/labelText which also acts as semantic labels sometimes,
    // wait, we can just find them by TextField or their semantics directly. But if Semantics doesn't work, we can find by type and index or hintText.
    await tester.enterText(find.widgetWithText(TextFormField, 'İsim Soyisim'), 'Test User');
    await tester.enterText(find.widgetWithText(TextFormField, 'Kullanıcı Adı'), 'testuser');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'password123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Gün').first, '01');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ay').first, '01');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yıl').first, '2000'); // Adult, no parental consent needed
    await tester.pumpAndSettle();
  }

  testWidgets('shows error when username is already in use', (WidgetTester tester) async {
    // Add existing user with same username
    await fakeFirestore.collection('users').add({'username': 'testuser'});

    await tester.pumpWidget(createTestWidget());
    await fillForm(tester);

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Bu kullanıcı adı zaten alınmış.'), findsOneWidget);
  });

  testWidgets('shows error when email is already in use', (WidgetTester tester) async {
    when(mockAuth.createUserWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await tester.pumpWidget(createTestWidget());
    await fillForm(tester);

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Bu e-posta adresi zaten kullanımda.'), findsOneWidget);
  });

  testWidgets('shows error when password is too weak', (WidgetTester tester) async {
    when(mockAuth.createUserWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    )).thenThrow(FirebaseAuthException(code: 'weak-password'));

    await tester.pumpWidget(createTestWidget());
    await fillForm(tester);

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Şifre çok zayıf.'), findsOneWidget);
  });

  testWidgets('shows generic error message for unknown exceptions', (WidgetTester tester) async {
    when(mockAuth.createUserWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    )).thenThrow(FirebaseAuthException(code: 'unknown'));

    await tester.pumpWidget(createTestWidget());
    await fillForm(tester);

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Bir hata oluştu.'), findsOneWidget);
  });
}
