import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:record/record.dart';

import 'package:blind_social/screens/chat_screen.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  setUpAll(() {
    registerFallbackValue(RecordConfig());
  });

  testWidgets('ChatScreen sendMessage performance test', (WidgetTester tester) async {
    final mockAudioRecorder = MockAudioRecorder();
    when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Pre-populate Firestore
    await fakeFirestore.collection('users').doc('test_uid').set({
      'display_preference': 'fullName',
      'fullName': 'Test User Full',
      'username': 'testuser',
    });

    await fakeFirestore.collection('chat_rooms').doc('test_room_id').set({
      'currentParticipants': 0,
      'ttl': '24h',
      'creatorId': 'creator_uid',
    });

    final mockStorage = MockFirebaseStorage();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        roomId: 'test_room_id',
        roomName: 'Test Room',
        audioRecorder: mockAudioRecorder,
        auth: mockAuth,
        firestore: fakeFirestore,
        storage: mockStorage,
      ),
    ));

    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    final sendButton = find.bySemanticsLabel('Mesajı Gönder butonu');
    expect(sendButton, findsOneWidget);

    final stopwatch = Stopwatch()..start();

    // Send multiple messages to simulate load
    for (int i = 0; i < 50; i++) {
      await tester.enterText(textField, 'Performance Test Message $i');
      await tester.tap(sendButton);
      await tester.pump();
    }

    stopwatch.stop();
    debugPrint('=== PERFORMANCE BENCHMARK RESULT ===');
    debugPrint('Time taken to send 50 messages: ${stopwatch.elapsedMilliseconds} ms');
    debugPrint('====================================');

    // Verify messages were sent
    final messages = await fakeFirestore.collection('chat_rooms').doc('test_room_id').collection('messages').get();
    expect(messages.docs.length, 50);
  });
}
