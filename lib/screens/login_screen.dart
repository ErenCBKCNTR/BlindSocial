import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // Navigate to Chat Rooms Screen on successful "login"
    Navigator.pushReplacementNamed(context, '/chat_rooms');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Giriş Ekranı Başlığı',
          child: const Text('Blind Social - Giriş'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Semantics(
              label: 'Hoş geldiniz mesajı',
              child: Text(
                'Blind Social\'a Hoş Geldiniz',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            Semantics(
              label: 'E-posta adresi giriş alanı',
              hint: 'E-posta adresinizi buraya yazın',
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  hintText: 'ornek@email.com',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Şifre giriş alanı',
              hint: 'Şifrenizi buraya yazın',
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  hintText: 'Şifreniz',
                ),
              ),
            ),
            const SizedBox(height: 40),
            Semantics(
              label: 'Giriş Yap butonu',
              hint: 'Sohbet odalarına gitmek için dokunun',
              button: true,
              child: ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('Giriş Yap'),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Kayıt Ol butonu',
              hint: 'Yeni bir hesap oluşturmak için dokunun',
              button: true,
              child: OutlinedButton(
                onPressed: () {
                  // Registration logic could go here
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.cyan, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Kayıt Ol',
                  style: TextStyle(color: Colors.cyan, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
