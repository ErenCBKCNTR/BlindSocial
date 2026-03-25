import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/chat_rooms_screen.dart';
import 'screens/update_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDjVZZqS6EIxxjulS01zqAChH74DfLlf7E',
        appId: '1:122600853691:web:7b215d6b1b8a5c946c999e',
        messagingSenderId: '122600853691',
        projectId: 'blind-social-a718c',
        storageBucket: 'blind-social-a718c.firebasestorage.app',
      ),
    );
    runApp(const BlindSocialApp());
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    runApp(const FirebaseErrorApp());
  }
}

class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.highContrastTheme,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Semantics(
              label: 'Bir sorun oluştu, lütfen internet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın',
              child: const Text(
                'Bir sorun oluştu, lütfen internet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlindSocialApp extends StatefulWidget {
  const BlindSocialApp({super.key});

  @override
  State<BlindSocialApp> createState() => _BlindSocialAppState();
}

class _BlindSocialAppState extends State<BlindSocialApp> {
  late Future<Map<String, dynamic>> _updateCheckFuture;

  @override
  void initState() {
    super.initState();
    _updateCheckFuture = _checkVersion();
  }

  Future<Map<String, dynamic>> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = semver.Version.parse(packageInfo.version);

      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final minVersionStr = data['min_version'] as String? ?? "1.0.0";
        final updateUrl = data['update_url'] as String? ?? "";
        final minVersion = semver.Version.parse(minVersionStr);

        if (currentVersion < minVersion) {
          return {'required': true, 'url': updateUrl};
        }
      }
    } catch (e) {
      debugPrint('Version check error: $e');
    }
    return {'required': false};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _updateCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.highContrastTheme,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Semantics(
                  label: 'Sürüm kontrol ediliyor, lütfen bekleyin',
                  child: CircularProgressIndicator(strokeWidth: 6, color: Colors.yellow),
                ),
              ),
            ),
          );
        }

        final updateData = snapshot.data ?? {'required': false};

        if (updateData['required'] == true) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.highContrastTheme,
            home: UpdateScreen(updateUrl: updateData['url'] ?? ""),
          );
        }

        return MaterialApp(
          title: 'Blind Social',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.highContrastTheme,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/chat_rooms': (context) => const ChatRoomsScreen(),
          },
        );
      },
    );
  }
}
