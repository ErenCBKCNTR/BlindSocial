import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/chat_rooms_screen.dart';
import 'screens/update_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlindSocialApp());
}

class BlindSocialApp extends StatefulWidget {
  const BlindSocialApp({super.key});

  @override
  State<BlindSocialApp> createState() => _BlindSocialAppState();
}

class _BlindSocialAppState extends State<BlindSocialApp> {
  late Future<Map<String, dynamic>> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<Map<String, dynamic>> _initialize() async {
    try {
      // Step 1: Initialize Firebase with a 3-second timeout
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDjVZZqS6EIxxjulS01zqAChH74DfLlf7E',
          appId: '1:122600853691:web:7b215d6b1b8a5c946c999e',
          messagingSenderId: '122600853691',
          projectId: 'blind-social-a718c',
          storageBucket: 'blind-social-a718c.firebasestorage.app',
        ),
      ).timeout(const Duration(seconds: 3));

      // Step 2: Check for mandatory updates
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = semver.Version.parse(packageInfo.version);

      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get()
          .timeout(const Duration(seconds: 2));

      if (doc.exists) {
        final data = doc.data()!;
        final minVersionStr = data['min_version'] as String? ?? "1.0.0";
        final currentVersionStr = data['current_version'] as String? ?? "1.0.0";
        final updateUrl = data['update_url'] as String? ?? "";
        final minVersion = semver.Version.parse(minVersionStr);
        final latestVersion = semver.Version.parse(currentVersionStr);

        if (currentVersion < minVersion) {
          return {'required': true, 'url': updateUrl};
        } else if (currentVersion < latestVersion) {
          return {'recommended': true, 'url': updateUrl};
        }
      }
    } catch (e) {
      debugPrint('Initialization/Version check error (Silent Fallback): $e');
      // If initialization fails or times out, we continue to the app to avoid a blank screen
    }
    return {'required': false};
  }

  @override
  Widget build(BuildContext context) {
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
      home: FutureBuilder<Map<String, dynamic>>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          final updateData = snapshot.data ?? {'required': false};
          if (updateData['required'] == true) {
            return UpdateScreen(updateUrl: updateData['url'] ?? "");
          }

          // Recommendation logic after auth or first load
          if (updateData['recommended'] == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ScaffoldMessenger.maybeOf(context) != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Semantics(
                      label:
                          'Yeni bir sürüm mevcut, lütfen en iyi deneyim için uygulamayı güncelleyin',
                      child: Text(
                          'Yeni bir sürüm mevcut, lütfen en iyi deneyim için uygulamayı güncelleyin'),
                    ),
                    backgroundColor: Colors.cyan,
                    action: SnackBarAction(
                        label: 'GÜNCELLE',
                        textColor: Colors.black,
                        onPressed: () {
                          launchUrl(Uri.parse(updateData['url']),
                              mode: LaunchMode.externalApplication);
                        }),
                  ),
                );
              }
            });
          }

          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/chat_rooms': (context) => const ChatRoomsScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Yükleniyor, lütfen bekleyin',
              child: const CircularProgressIndicator(
                strokeWidth: 10,
                color: Colors.yellow,
              ),
            ),
            const SizedBox(height: 40),
            Semantics(
              label: 'Uygulama başlatılıyor içeriği',
              child: const Text(
                'Yükleniyor...',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
