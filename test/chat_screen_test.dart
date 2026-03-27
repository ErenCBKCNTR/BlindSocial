import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:blind_social/screens/chat_screen.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}
class MockCustomFirebaseStorage extends Mock implements FirebaseStorage {}
class MockReference extends Mock implements Reference {}

class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return 'fake/temp/path';
  }
}

void main() {
  setUpAll(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    registerFallbackValue(RecordConfig());
  });

  testWidgets('ChatScreen handles audio recording start error gracefully', (WidgetTester tester) async {
    // 1. Setup mock AudioRecorder
    final mockAudioRecorder = MockAudioRecorder();

    // Stub permissions and mock throwing an error on start
    when(() => mockAudioRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => false);
    when(() => mockAudioRecorder.start(any(), path: any(named: 'path')))
        .thenThrow(Exception('Simulated recording start error'));

    // Needed to clean up / not crash during dispose
    when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

    // 2. Setup mock Firebase dependencies
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Pre-populate Firestore with necessary data
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

    // 3. Pump the ChatScreen
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

    // Wait for the FutureBuilder / StreamBuilders and initial effects to settle
    await tester.pumpAndSettle();

    // 4. Find and tap the record button
    final recordButtonFinder = find.bySemanticsLabel('Sesli Mesaj Kaydet');
    expect(recordButtonFinder, findsOneWidget);

    await tester.tap(recordButtonFinder);
    await tester.pump(); // Process the UI update

    // 5. Verify the error handling
    // We expect the recording start to throw an error which should be caught.
    // As a result, _isRecording should still be false.
    // The UI should still show "Sesli Mesaj Kaydet" and not "Kaydı Durdur ve Gönder".
    expect(find.bySemanticsLabel('Sesli Mesaj Kaydet'), findsOneWidget);
    expect(find.bySemanticsLabel('Kaydı Durdur ve Gönder'), findsNothing);

    // We also shouldn't see the red recording duration text
    expect(find.textContaining('Kayıt Yapılıyor:'), findsNothing);
  });

  testWidgets('ChatScreen handles audio upload error gracefully', (WidgetTester tester) async {
    // 1. Setup mock AudioRecorder
    final mockAudioRecorder = MockAudioRecorder();

    // Stub permissions to true
    when(() => mockAudioRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => false);

    // Stub start recording
    when(() => mockAudioRecorder.start(any(), path: any(named: 'path')))
        .thenAnswer((_) async {});

    // Stub stop recording to return a dummy file path
    when(() => mockAudioRecorder.stop()).thenAnswer((_) async => 'dummy/path/audio.m4a');

    // Needed to clean up / not crash during dispose
    when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

    // 2. Setup mock Firebase dependencies
    final user = MockUser(
      isAnonymous: false,
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    final mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

    final fakeFirestore = FakeFirebaseFirestore();

    // Pre-populate Firestore with necessary data
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

    // Setup custom MockFirebaseStorage to throw exception on putFile
    final mockStorage = MockCustomFirebaseStorage();
    final mockRef1 = MockReference();
    final mockRef2 = MockReference();
    final mockRef3 = MockReference();
    final mockRef4 = MockReference();

    // Register Fallback Value for File
    registerFallbackValue(File('dummy_file.txt'));

    // Chain the references
    when(() => mockStorage.ref()).thenReturn(mockRef1);
    when(() => mockRef1.child(any())).thenReturn(mockRef2);
    when(() => mockRef2.child(any())).thenReturn(mockRef3);
    when(() => mockRef3.child(any())).thenReturn(mockRef4);

    // Stub putFile to throw exception to simulate upload error
    when(() => mockRef4.putFile(any())).thenThrow(FirebaseException(plugin: 'firebase_storage', code: 'canceled'));

    // 3. Pump the ChatScreen
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

    // Wait for the FutureBuilder / StreamBuilders and initial effects to settle
    await tester.pumpAndSettle();

    // 4. Find and tap the record button to START recording
    final startRecordButton = find.bySemanticsLabel('Sesli Mesaj Kaydet');
    expect(startRecordButton, findsOneWidget);

    // We invoke the internal _uploadVoiceMessage by triggering the state change.
    // However, to do that easily, we can just trigger it using the UI.
    // Wait, the UI uses `path != null` from `await _audioRecorder.stop()`.
    await tester.tap(startRecordButton);

    // Process the Future from start()
    await tester.pump();

    // Fast forward for timer
    await tester.pump(const Duration(seconds: 1));

    // Wait for state to change to _isRecording = true
    await tester.pumpAndSettle();

    // Tap to stop and trigger upload
    final stopRecordButton = find.bySemanticsLabel('Kaydı Durdur ve Gönder');
    expect(stopRecordButton, findsOneWidget);
    await tester.tap(stopRecordButton);

    // Process the Future from stop() and uploadVoiceMessage()
    await tester.pump();

    // Process the delayed setState from catch
    await tester.pumpAndSettle();

    // 6. Verify the error handling in UI
    expect(find.text('Sesli mesaj yüklenirken hata oluştu.'), findsOneWidget);
  });
}
