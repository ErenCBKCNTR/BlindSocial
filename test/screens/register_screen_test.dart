import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/screens/register_screen.dart';

void main() {
  testWidgets('RegisterScreen handles invalid date without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: RegisterScreen(),
    ));

    // Wait for initial animations (if any)
    await tester.pumpAndSettle();

    // Find the text fields by checking their hintText via their widget properties
    Finder findTextFieldByHint(String hint) {
      return find.byWidgetPredicate(
        (Widget widget) {
          if (widget is TextField) {
            return widget.decoration?.hintText == hint;
          }
          return false;
        }
      );
    }

    final dayField = findTextFieldByHint('Gün');
    final monthField = findTextFieldByHint('Ay');
    final yearField = findTextFieldByHint('Yıl');

    expect(dayField, findsOneWidget);
    expect(monthField, findsOneWidget);
    expect(yearField, findsOneWidget);

    // Enter an invalid date that forces ArgumentError from DateTime()
    // According to Dart docs, max year is roughly 275759. 275760 with later months throws.
    await tester.enterText(dayField, '14');
    await tester.pump();

    await tester.enterText(monthField, '9');
    await tester.pump();

    await tester.enterText(yearField, '275760');

    // The framework will catch any exceptions thrown during the build or event handler.
    // If _checkAge doesn't catch the ArgumentError, tester.pump() will throw.

    // This expects that no unhandled exceptions happen
    try {
      await tester.pump();
      await tester.pumpAndSettle();
    } catch (e) {
      fail('Expected no crash on invalid date, but got: $e');
    }

    // As a result of the exception being caught, _isUnderage shouldn't change
    // Since it starts at false, the Parental Consent checkbox shouldn't appear
    final parentalConsentCheckbox = find.byType(Checkbox);
    expect(parentalConsentCheckbox, findsNothing);
  });
}
