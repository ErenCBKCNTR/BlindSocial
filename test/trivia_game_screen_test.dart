import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/screens/games/trivia_game_screen.dart';

void main() {
  testWidgets('TriviaGameScreen initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TriviaGameScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
