import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/screens/games/game_room_screen.dart';
import 'package:blind_social/screens/games/trivia_game_screen.dart';

void main() {
  testWidgets('GameRoomScreen displays quiz card and navigates to TriviaGameScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameRoomScreen()));

    expect(find.text('Bilgi Yarışması'), findsOneWidget);

    await tester.tap(find.text('Bilgi Yarışması'));
    await tester.pumpAndSettle();

    expect(find.byType(TriviaGameScreen), findsOneWidget);
  });
}
