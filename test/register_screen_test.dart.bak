import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'package:blind_social/screens/register_screen.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();

    // Mock the permission channel to prevent hangs/errors in Connectivity checks
    const MethodChannel('dev.fluttercommunity.plus/connectivity').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi']; // Mock as connected, returning a list because checkConnectivity returns List<ConnectivityResult> in v7+
      }
      return null;
    });
  });

  Widget createRegisterScreen() {
    return MaterialApp(
      home: RegisterScreen(
        auth: mockAuth,
        firestore: fakeFirestore,
      ),
    );
  }

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders all essential form fields correctly', (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics(); // Enable semantics for testing

      await tester.pumpWidget(createRegisterScreen());

      // Ensure the widget tree is fully built
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'İsim Soyisim'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Kullanıcı Adı'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'E-posta'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Şifre'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Gün'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Ay'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Yıl'), findsOneWidget);

      expect(find.widgetWithText(ElevatedButton, 'Kayıt Ol'), findsOneWidget);

      semanticsHandle.dispose();
    });

    testWidgets('shows validation errors when fields are empty', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterScreen());

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();

      expect(find.text('Boş bırakılamaz'), findsWidgets);
      expect(find.text('En az 6 karakter'), findsOneWidget);
    });

    testWidgets('shows parental consent checkbox for underage users and enforces checking it', (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(createRegisterScreen());

      await tester.pumpAndSettle();

      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'İsim Soyisim'), 'Underage User');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Kullanıcı Adı'), 'underage');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'E-posta'), 'underage@test.com');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Şifre'), 'password123');

      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Gün'), '1');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Ay'), '1');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Yıl'), '2020');

      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();

      expect(find.text('Ebeveyn izni kutusunu işaretlemelisiniz.'), findsOneWidget);

      semanticsHandle.dispose();
    });

    testWidgets('successfully registers a user and navigates to chat rooms', (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics();

      final mockObserver = MockNavigatorObserver();

      await tester.pumpWidget(MaterialApp(
        home: RegisterScreen(
          auth: mockAuth,
          firestore: fakeFirestore,
        ),
        navigatorObservers: [mockObserver],
        routes: {
          '/chat_rooms': (context) => const Scaffold(body: Text('Chat Rooms')),
        },
      ));

      await tester.pumpAndSettle();

      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'İsim Soyisim'), 'Test User');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Kullanıcı Adı'), 'testuser');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'E-posta'), 'test@example.com');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Şifre'), 'password123');

      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Gün'), '1');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Ay'), '1');
      await tester.enterText(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Yıl'), '1990');

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();

      expect(mockAuth.currentUser, isNotNull);
      expect(mockAuth.currentUser?.email, 'test@example.com');

      final userDocs = await fakeFirestore.collection('users').get();
      expect(userDocs.docs.length, 1);

      final userData = userDocs.docs.first.data();
      expect(userData['username'], 'testuser');
      expect(userData['fullName'], 'Test User');
      expect(userData['email'], 'test@example.com');
      expect(userData['role_id'], 2);

      expect(find.text('Chat Rooms'), findsOneWidget);

      semanticsHandle.dispose();
    });
  });
}

class MockNavigatorObserver extends NavigatorObserver {
  List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
