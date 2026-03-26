import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _fullNameController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _fullNameController.text = data['fullName'] ?? '';
        _username = data['username'] ?? '';
        if (data['birthDate'] != null) {
          final date = (data['birthDate'] as Timestamp).toDate();
          _dayController.text = date.day.toString();
          _monthController.text = date.month.toString();
          _yearController.text = date.year.toString();
        }
      });
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);

    if (day == null || month == null || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir doğum tarihi giriniz.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullName': _fullNameController.text.trim(),
        'birthDate': Timestamp.fromDate(DateTime(year, month, day)),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreler eşleşmiyor.')));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az 6 karakter olmalı.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.currentUser!.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata oluştu.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(label: 'Hesabım Ekranı', child: const Text('Hesabım')),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Kullanıcı Adı Bilgisi',
                  child: Text('Kullanıcı Adı: $_username', style: const TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
                Semantics(
                  label: 'İsim Soyisim düzenleme alanı',
                  child: TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'İsim Soyisim'),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Doğum Tarihi',
                    style: TextStyle(color: Colors.cyan, fontSize: 18)),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Gün',
                        child: TextFormField(
                          controller: _dayController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Gün'),
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
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Profili Güncelle butonu',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    child: const Text('Bilgileri Kaydet'),
                  ),
                ),
                const Divider(height: 60, color: Colors.cyan, thickness: 2),
                const Text('Şifre Değiştir', style: TextStyle(color: Colors.yellow, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Yeni Şifre alanı',
                  child: TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: 'Yeni Şifre Tekrar alanı',
                  child: TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre Tekrar'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Şifreyi Güncelle butonu',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                    child: const Text('Şifreyi Güncelle', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
