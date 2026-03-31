import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blind_social/screens/update_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? url;
  LaunchOptions? options;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    this.options = options;
    return true;
  }
}

void main() {
  late MockUrlLauncher mockUrlLauncher;

  setUp(() {
    mockUrlLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockUrlLauncher;
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: UpdateScreen(updateUrl: 'https://example.com/update'),
    );
  }

  testWidgets('renders all UI elements correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
    expect(find.text('Güncelleme Gerekli'), findsOneWidget);
    expect(
        find.text(
            'Uygulamanın daha iyi ve sorunsuz çalışması için yeni sürümü yüklemelisiniz.'),
        findsOneWidget);
    expect(find.text('Uygulamayı Güncelle'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });


  testWidgets('launches WhatsApp URL when button is tapped', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(mockUrlLauncher.url, startsWith('https://wa.me/905345991728'));
    expect(mockUrlLauncher.options?.mode, PreferredLaunchMode.externalApplication);
  });
}
