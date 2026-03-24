import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/chat_rooms_screen.dart';

void main() {
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
      },
    );
  }
}
