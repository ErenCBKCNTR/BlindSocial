import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Semantics(
        label: 'Hata Mesajı Penceresi',
        focused: true,
        child: AlertDialog(
          title: const Text('Hata'),
          content: Text(message),
          actions: [
            Semantics(
              label: 'Tamam butonu',
              hint: 'Pencereyi kapatmak için dokunun',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chat_rooms');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showErrorDialog(e.message ?? 'Giriş yapılamadı.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chat_rooms');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showErrorDialog(e.message ?? 'Kayıt yapılamadı.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                    label: 'E-posta adresi giriş alanı',
                    hint: 'E-posta adresinizi buraya yazın. Örnek: ornek@email.com',
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
                    label: 'Kayıt Ol butonu',
                    hint: 'Yeni bir hesap oluşturmak için dokunun',
                    button: true,
                    child: OutlinedButton(
                      onPressed: _handleRegister,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.cyan, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Kayıt Ol',
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
