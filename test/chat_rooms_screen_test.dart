import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:blind_social/screens/chat_rooms_screen.dart';

void main() {
  testWidgets('ChatRoomsScreen displays empty state when there are no rooms', (WidgetTester tester) async {
    // 1. Setup mock Firebase dependencies
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Pre-populate Firestore with necessary data (complete profile)
    await fakeFirestore.collection('users').doc('test_uid').set({
      'display_preference': 'fullName',
      'fullName': 'Test User Full',
      'username': 'testuser',
      'birthDate': DateTime(2000, 1, 1),
    });

    // 2. Pump the ChatRoomsScreen
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomsScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    ));

    // Wait for the FutureBuilder / StreamBuilders and initial effects to settle
    await tester.pumpAndSettle();

    // 3. Verify empty state
    expect(find.text('Henüz bir sohbet odası bulunmuyor.'), findsOneWidget);
    expect(find.byIcon(Icons.forum), findsOneWidget);
  });

  testWidgets('ChatRoomsScreen displays list of rooms when they exist', (WidgetTester tester) async {
    // 1. Setup mock Firebase dependencies
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Pre-populate Firestore with necessary data (complete profile)
    await fakeFirestore.collection('users').doc('test_uid').set({
      'display_preference': 'fullName',
      'fullName': 'Test User Full',
      'username': 'testuser',
      'birthDate': DateTime(2000, 1, 1),
    });

    // Populate chat rooms
    await fakeFirestore.collection('chat_rooms').doc('room1').set({
      'name': 'Room 1',
      'maxCapacity': 5,
      'currentParticipants': 2,
      'createdAt': DateTime.now().subtract(const Duration(minutes: 5)),
      'creatorId': 'some_other_uid',
    });

    await fakeFirestore.collection('chat_rooms').doc('room2').set({
      'name': 'Locked Room',
      'maxCapacity': 10,
      'currentParticipants': 9,
      'password': '123',
      'createdAt': DateTime.now(),
      'creatorId': 'some_other_uid',
    });

    // 2. Pump the ChatRoomsScreen
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomsScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    ));

    // Wait for the FutureBuilder / StreamBuilders and initial effects to settle
    await tester.pumpAndSettle();

    // 3. Verify room listings
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Kapasite: 2 / 5'), findsOneWidget);

    expect(find.text('Locked Room'), findsOneWidget);
    expect(find.text('Kapasite: 9 / 10'), findsOneWidget);

    // Check for lock icon on locked room
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('ChatRoomsScreen shows incomplete profile view when profile is missing data', (WidgetTester tester) async {
    // 1. Setup mock Firebase dependencies
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Do NOT populate the 'users' collection to simulate incomplete profile
    // Or set it with missing fields
    await fakeFirestore.collection('users').doc('test_uid').set({
      'display_preference': 'fullName',
      // Missing 'fullName', 'username', 'birthDate'
    });

    // 2. Pump the ChatRoomsScreen
    await tester.pumpWidget(MaterialApp(
      home: ChatRoomsScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    ));

    // Wait for the FutureBuilder / StreamBuilders and initial effects to settle
    await tester.pumpAndSettle();

    // 3. Verify incomplete profile state
    expect(find.text('Lütfen profilinizi tamamlayın'), findsOneWidget);

    // Check that the bottom sheet dialog also appears
    expect(find.text('Profil Tamamlama Gerekli'), findsOneWidget);
  });
}
