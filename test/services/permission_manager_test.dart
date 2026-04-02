import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:blind_social/services/permission_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter.baseflow.com/permissions/methods');

  int mockCheckStatus = 1; // granted
  Map<int, int> mockRequestResult = {};
  bool openAppSettingsCalled = false;
  bool requestPermissionsCalled = false;

  setUp(() {
    mockCheckStatus = 1; // granted
    mockRequestResult = {};
    openAppSettingsCalled = false;
    requestPermissionsCalled = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkPermissionStatus') {
        return mockCheckStatus;
      } else if (methodCall.method == 'requestPermissions') {
        requestPermissionsCalled = true;
        // Arguments is a List<int>
        final List<dynamic> args = methodCall.arguments;
        final result = <int, int>{};
        for (var arg in args) {
          result[arg as int] = mockRequestResult[arg] ?? 1; // default to granted
        }
        return result;
      } else if (methodCall.method == 'openAppSettings') {
        openAppSettingsCalled = true;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PermissionManager Tests', () {
    testWidgets('requestNotificationPermission - already granted', (WidgetTester tester) async {
      // 1 = granted
      mockCheckStatus = 1;

      // Create a dummy context
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              await PermissionManager.requestNotificationPermission(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(requestPermissionsCalled, isFalse);
    });

    testWidgets('requestNotificationPermission - denied initially', (WidgetTester tester) async {
      // 0 = denied
      mockCheckStatus = 0;
      // when requested, let's say it returns granted (1)
      mockRequestResult = {Permission.notification.value: 1};

      // Create a dummy context
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              await PermissionManager.requestNotificationPermission(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(requestPermissionsCalled, isTrue);
    });
  });

  group('requestBsBibPermissions Tests', () {
    testWidgets('requestBsBibPermissions - all granted', (WidgetTester tester) async {
      // All permissions return granted (1)
      mockRequestResult = {
        Permission.camera.value: 1,
        Permission.microphone.value: 1,
        Permission.location.value: 1,
        Permission.bluetoothConnect.value: 1,
      };

      bool? result;

      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await PermissionManager.requestBsBibPermissions(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('requestBsBibPermissions - one permanently denied', (WidgetTester tester) async {
      // 4 = permanentlyDenied
      mockRequestResult = {
        Permission.camera.value: 4,
        Permission.microphone.value: 1,
        Permission.location.value: 1,
        Permission.bluetoothConnect.value: 1,
      };

      bool? result;

      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await PermissionManager.requestBsBibPermissions(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('İzin Gerekli'), findsOneWidget);
      expect(find.text('Ayarlara Git'), findsOneWidget);

      // Tap 'Ayarlara Git'
      await tester.tap(find.text('Ayarlara Git'));
      await tester.pumpAndSettle();

      expect(openAppSettingsCalled, isTrue);
    });

    testWidgets('requestBsBibPermissions - one permanently denied - tap İptal', (WidgetTester tester) async {
      // 4 = permanentlyDenied
      mockRequestResult = {
        Permission.camera.value: 4,
        Permission.microphone.value: 1,
        Permission.location.value: 1,
        Permission.bluetoothConnect.value: 1,
      };

      bool? result;

      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await PermissionManager.requestBsBibPermissions(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap 'İptal'
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(openAppSettingsCalled, isFalse);
    });

    testWidgets('requestBsBibPermissions - one denied', (WidgetTester tester) async {
      // 0 = denied
      mockRequestResult = {
        Permission.camera.value: 0,
        Permission.microphone.value: 1,
        Permission.location.value: 1,
        Permission.bluetoothConnect.value: 1,
      };

      bool? result;

      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await PermissionManager.requestBsBibPermissions(context);
            },
            child: const Text('Test'),
          ),
        );
      })));

      await tester.tap(find.text('Test'));
      await tester.pump(); // Pump to start SnackBar animation

      expect(result, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Bu özelliği kullanabilmek için izne ihtiyacımız var'), findsOneWidget);

      await tester.pumpAndSettle(); // Finish animation
    });
  });
}
