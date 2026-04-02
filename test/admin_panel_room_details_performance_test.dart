import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:blind_social/screens/admin_panel_room_details.dart';
import 'dart:typed_data';

void main() {
  testWidgets('AdminPanelRoomDetails _deleteRoom performance benchmark', (WidgetTester tester) async {
    final fakeFirestore = FakeFirebaseFirestore();
    final mockStorage = MockFirebaseStorage();

    // Create a room document
    final roomData = {
      'name': 'Test Room',
      'numericId': 12345,
      'creatorId': 'test_user_id',
      'maxCapacity': 10,
      'ttlPreference': '24h',
      'createdAt': Timestamp.now(),
    };
    final roomRef = fakeFirestore.collection('chat_rooms').doc('test_room_id');
    await roomRef.set(roomData);

    // Add 10 messages (reduced from 100)
    for (int i = 0; i < 10; i++) {
      await roomRef.collection('messages').add({'text': 'message $i'});
    }

    // Add 10 files to storage (reduced from 50)
    final folderRef = mockStorage.ref().child('recordings').child('12345');
    for (int i = 0; i < 10; i++) {
        await folderRef.child('file_$i.m4a').putData(Uint8List.fromList([0, 1, 2, 3]));
    }

    await tester.pumpWidget(MaterialApp(
      home: AdminPanelRoomDetails(
        room: roomData,
        roomRef: roomRef,
      ),
    ));

    await tester.pumpAndSettle();

    // Trigger delete
    final deleteButton = find.text('Odayı Sil');
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    final confirmButton = find.text('SİL');

    final stopwatch = Stopwatch()..start();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    stopwatch.stop();

    debugPrint('=== DELETE ROOM PERFORMANCE BENCHMARK ===');
    debugPrint('Time taken to delete room with 10 messages and 10 files: ${stopwatch.elapsedMilliseconds} ms');
    debugPrint('=========================================');

    // Verify deletion
    final roomDoc = await roomRef.get();
    expect(roomDoc.exists, false);

    final messages = await roomRef.collection('messages').get();
    expect(messages.docs.isEmpty, true);

    final listResult = await folderRef.listAll();
    expect(listResult.items.isEmpty, true);
  });
}
