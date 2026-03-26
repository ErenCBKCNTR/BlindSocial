import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _checkRememberMe();
  }

  Future<void> _checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });

    if (_rememberMe && _auth.currentUser != null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chat_rooms');
      }
    } else if (!_rememberMe) {
      await _auth.signOut();
    }
  }

  Future<void> _updateRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', value);
    setState(() {
      _rememberMe = value;
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _translateAuthError(String code) {
    switch (code) {
      case 'weak-password':
        return 'Şifreniz çok zayıf. En az 6 karakter olmalıdır.';
      case 'invalid-email':
        return 'Geçersiz bir e-posta adresi girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'invalid-credential':
        return 'Giriş bilgileri hatalı veya süresi dolmuş.';
      default:
        return 'Bir hata oluştu, lütfen tekrar deneyin.';
    }
  }

  void _showThemedError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          label: 'Hata bildirimi: $message',
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String email = identifier;

      // If identifier doesn't contain '@', it's a username
      if (!identifier.contains('@')) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: identifier.toLowerCase())
            .get();

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(code: 'user-not-found');
        }
        email = userQuery.docs.first.get('email');
      }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chat_rooms');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showThemedError(_translateAuthError(e.code));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Şifremi Unuttum', style: TextStyle(color: Colors.yellow)),
        content: const Text(
          'Bu özellik şu anda devre dışıdır, lütfen yönetici ile irtibata geçiniz.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
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
      body: _isLoading
          ? Center(
              child: Semantics(
                label: 'İşlem yapılıyor, lütfen bekleyin',
                child: const CircularProgressIndicator(
                  strokeWidth: 6,
                ),
              ),
            )
          : SingleChildScrollView(
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
                    label: 'E-posta veya Kullanıcı Adı giriş alanı',
                    hint: 'E-posta adresinizi veya kullanıcı adınızı buraya yazın.',
                    child: TextField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta veya Kullanıcı Adı',
                        hintText: 'ornek@email.com veya kullanıcıadı',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: Semantics(
                        label: 'Şifrenizi mi unuttunuz?',
                        child: const Text(
                          'Şifrenizi mi unuttunuz?',
                          style: TextStyle(color: Colors.cyan, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Şifre giriş alanı',
                    hint: 'Şifrenizi buraya yazın. En az 6 karakter olmalıdır.',
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        hintText: 'Şifreniz',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Beni Hatırla',
                    hint: _rememberMe
                        ? 'Beni hatırla seçili. Otomatik giriş yapmak için işaretli tutun.'
                        : 'Beni hatırla seçili değil. Otomatik giriş yapmak için işaretleyin.',
                    child: Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (val) => _updateRememberMe(val ?? false),
                          activeColor: Colors.yellow,
                          checkColor: Colors.black,
                        ),
                        Text(
                          'Beni Hatırla',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
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
                    label: 'Blind Social Hesabı Oluştur butonu',
                    hint: 'Yeni bir hesap oluşturmak için dokunun',
                    button: true,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.cyan, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Blind Social Hesabı Oluştur',
                        style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
