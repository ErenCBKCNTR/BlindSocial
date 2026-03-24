import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/chat_rooms_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: For a real app, FirebaseOptions should be provided here.
  // In this sandbox environment, we initialize with default options if available.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const BlindSocialApp());
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
        // Note: '/chat' is handled via MaterialPageRoute because it requires parameters
      },
    );
  }
}
