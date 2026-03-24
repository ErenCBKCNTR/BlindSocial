import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/chat_rooms_screen.dart';

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

class BlindSocialApp extends StatelessWidget {
  const BlindSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blind Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.highContrastTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/chat_rooms': (context) => const ChatRoomsScreen(),
      },
    );
  }
}
