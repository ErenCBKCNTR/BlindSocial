import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/screens/games/trivia_game_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  testWidgets('TriviaGameScreen initializes correctly', (WidgetTester tester) async {
    final fakeFirestore = FakeFirebaseFirestore();
    await tester.pumpWidget(MaterialApp(home: TriviaGameScreen(firestore: fakeFirestore)));
    expect(find.text('Trivia Ayarları'), findsOneWidget);
  });
}
