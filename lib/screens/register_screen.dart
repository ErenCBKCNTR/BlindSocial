import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  bool _isLoading = false;
  bool _isUnderage = false;
  bool _parentalConsent = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _checkAge() {
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);

    if (day != null && month != null && year != null) {
      try {
        final birthDate = DateTime(year, month, day);
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        setState(() {
          _isUnderage = age < 15;
        });
      } catch (e) {
        // Invalid date
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUnderage && !_parentalConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ebeveyn izni kutusunu işaretlemelisiniz.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Check unique username
      final username = _usernameController.text.trim().toLowerCase();
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (userQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(code: 'username-already-in-use', message: 'Bu kullanıcı adı zaten alınmış.');
      }

      // 2. Create Auth User
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        // 3. Create Firestore Document
        final day = int.parse(_dayController.text);
        final month = int.parse(_monthController.text);
        final year = int.parse(_yearController.text);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': _fullNameController.text.trim(),
          'username': username,
          'email': user.email,
          'birthDate': Timestamp.fromDate(DateTime(year, month, day)),
          'role_id': 2, // Standard User
          'display_preference': 'username',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.pushReplacementNamed(context, '/chat_rooms');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Bir hata oluştu.';
      if (e.code == 'username-already-in-use') message = e.message!;
      if (e.code == 'email-already-in-use') message = 'Bu e-posta adresi zaten kullanımda.';
      if (e.code == 'weak-password') message = 'Şifre çok zayıf.';

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Kayıt Olma Ekranı Başlığı',
          child: const Text('Blind Social Hesabı Oluştur'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: 'İsim Soyisim giriş alanı',
                      child: TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(labelText: 'İsim Soyisim'),
                        validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'Kullanıcı Adı giriş alanı',
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                        validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'E-posta giriş alanı',
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                        validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'Şifre giriş alanı',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Şifre'),
                        validator: (v) => v!.length < 6 ? 'En az 6 karakter' : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Doğum Tarihi', style: TextStyle(color: Colors.cyan, fontSize: 18)),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Gün',
                            child: TextFormField(
                              controller: _dayController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Gün'),
                              onChanged: (_) => _checkAge(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            label: 'Ay',
                            child: TextFormField(
                              controller: _monthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Ay'),
                              onChanged: (_) => _checkAge(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            label: 'Yıl',
                            child: TextFormField(
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Yıl'),
                              onChanged: (_) => _checkAge(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isUnderage)
                      Semantics(
                        label: 'Ebeveyn İzni onay kutusu',
                        child: Row(
                          children: [
                            Checkbox(
                              value: _parentalConsent,
                              onChanged: (v) => setState(() => _parentalConsent = v!),
                              activeColor: Colors.yellow,
                              checkColor: Colors.black,
                            ),
                            const Expanded(child: Text('Bu hesabı ebeveynlerin izniyle oluşturuyorum.', style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                    Semantics(
                      label: 'Hesabı Oluştur butonu',
                      button: true,
                      child: ElevatedButton(
                        onPressed: _handleRegister,
                        child: const Text('Kayıt Ol'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
