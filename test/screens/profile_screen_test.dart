import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:blind_social/screens/profile_screen.dart';
import 'package:mockito/mockito.dart';

// We use an interception pattern to trigger a network error only on `update`.
// This allows us to use FakeFirebaseFirestore for the initial load, and only fail on `update`.
class NetworkErrorMockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {
  final DocumentReference<Map<String, dynamic>> delegate;

  NetworkErrorMockDocumentReference(this.delegate);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) => delegate.get(options);

  @override
  Future<void> update(Map<Object, Object?> data) {
    throw Exception('network timeout');
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) => delegate.collection(collectionPath);
}

class NetworkErrorMockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {
  final CollectionReference<Map<String, dynamic>> delegate;

  NetworkErrorMockCollectionReference(this.delegate);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return NetworkErrorMockDocumentReference(delegate.doc(path));
  }

  @override
  Query<Map<String, dynamic>> where(Object field, {Object? isEqualTo, Object? isNotEqualTo, Object? isLessThan, Object? isLessThanOrEqualTo, Object? isGreaterThan, Object? isGreaterThanOrEqualTo, Object? arrayContains, Iterable<Object?>? arrayContainsAny, Iterable<Object?>? whereIn, Iterable<Object?>? whereNotIn, bool? isNull}) {
    return delegate.where(field, isEqualTo: isEqualTo, isNotEqualTo: isNotEqualTo, isLessThan: isLessThan, isLessThanOrEqualTo: isLessThanOrEqualTo, isGreaterThan: isGreaterThan, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo, arrayContains: arrayContains, arrayContainsAny: arrayContainsAny, whereIn: whereIn, whereNotIn: whereNotIn, isNull: isNull);
  }
}

class NetworkErrorMockFirestore extends Mock implements FirebaseFirestore {
  final FakeFirebaseFirestore delegate;

  NetworkErrorMockFirestore(this.delegate);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return NetworkErrorMockCollectionReference(delegate.collection(collectionPath));
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;

  setUp(() async {
    mockUser = MockUser(
      isAnonymous: false,
      uid: 'test_user_id',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    fakeFirestore = FakeFirebaseFirestore();

    // Initial user data
    await fakeFirestore.collection('users').doc('test_user_id').set({
      'fullName': 'Test User',
      'username': 'testuser',
      'display_preference': 'username',
      'birthDate': Timestamp.fromDate(DateTime(2000, 1, 1)),
      'username_last_changed': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
    });
  });

  Widget createWidgetUnderTest({FirebaseFirestore? customFirestore}) {
    return MaterialApp(
      home: ScaffoldMessenger(
        child: ProfileScreen(
          auth: mockAuth,
          firestore: customFirestore ?? fakeFirestore,
        ),
      ),
    );
  }

  testWidgets('successful profile update shows success SnackBar', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify initial data is loaded
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('testuser'), findsOneWidget);

    // Update fields
    await tester.enterText(find.widgetWithText(TextField, 'İsim Soyisim'), 'Updated Name');
    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'updateduser');
    await tester.enterText(find.widgetWithText(TextFormField, 'Gün'), '15');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ay'), '6');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yıl'), '1995');

    // Tap save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet'));
    await tester.pump(); // Start loading
    await tester.pumpAndSettle(); // Finish saving and showing SnackBar

    // Verify success message
    expect(find.text('Profil güncellendi.'), findsOneWidget);

    // Verify Firestore data was updated
    final doc = await fakeFirestore.collection('users').doc('test_user_id').get();
    expect(doc.data()!['fullName'], 'Updated Name');
    expect(doc.data()!['username'], 'updateduser');
  });

  testWidgets('error handled correctly when username is taken', (WidgetTester tester) async {
    // Add another user with the desired username
    await fakeFirestore.collection('users').doc('other_user_id').set({
      'username': 'takenuser',
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Update fields
    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'takenuser');

    // Tap save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet'));
    await tester.pump(); // Start loading
    await tester.pumpAndSettle(); // Finish saving and showing SnackBar

    // Verify error message
    expect(find.text('Bu kullanıcı adı zaten alınmış.'), findsOneWidget);
  });

  testWidgets('error handled correctly when username changed recently (cooldown)', (WidgetTester tester) async {
    // Set username_last_changed to 5 minutes ago
    await fakeFirestore.collection('users').doc('test_user_id').update({
      'username_last_changed': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))),
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Update fields
    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'newusername');

    // Tap save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet'));
    await tester.pump(); // Start loading
    await tester.pumpAndSettle(); // Finish saving and showing SnackBar

    // Verify error message (remaining time is around 10 minutes)
    expect(find.textContaining('dakika daha bekleyin'), findsOneWidget);
  });

  testWidgets('error handled correctly for missing fields', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Clear fields
    await tester.enterText(find.widgetWithText(TextField, 'İsim Soyisim'), '');

    // Tap save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet'));
    await tester.pump(); // Process dialog/snackbar

    // Verify validation error message
    expect(find.text('Lütfen tüm alanları doldurunuz.'), findsOneWidget);
  });

  testWidgets('error handled correctly for network error', (WidgetTester tester) async {
    final customFirestore = NetworkErrorMockFirestore(fakeFirestore);

    await tester.pumpWidget(createWidgetUnderTest(customFirestore: customFirestore));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Kullanıcı Adı'), 'newuser');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Bilgileri Kaydet'));
    await tester.pump(); // Start loading
    await tester.pumpAndSettle(); // Show error snackbar

    expect(find.text('Bağlantı hatası, lütfen internetinizi kontrol edin.'), findsOneWidget);
  });
}
