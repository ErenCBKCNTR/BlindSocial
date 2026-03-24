import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/main.dart';

void main() {
  testWidgets('Login screen loads and shows welcome message', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BlindSocialApp());

    // Verify that the login screen is showing.
    expect(find.text('Blind Social\'a Hoş Geldiniz'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });

  testWidgets('Navigation to chat rooms works', (WidgetTester tester) async {
    await tester.pumpWidget(const BlindSocialApp());

    // Tap the Login button
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    // Verify that we are on the Chat Rooms screen
    expect(find.text('Sohbet Odaları'), findsOneWidget);
    expect(find.text('Henüz bir sohbet odası bulunmuyor.'), findsOneWidget);
  });
}
