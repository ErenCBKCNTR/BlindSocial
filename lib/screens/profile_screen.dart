import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const ProfileScreen({super.key, this.auth, this.firestore});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showPasswordFields = false;
  String _displayPreference = 'username';
  DateTime? _usernameLastChanged;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _fullNameController.text = data['fullName'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _displayPreference = data['display_preference'] ?? 'username';
        if (data['username_last_changed'] != null) {
          _usernameLastChanged =
              (data['username_last_changed'] as Timestamp).toDate();
        }
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

    final name = _fullNameController.text.trim();
    final newUsername = _usernameController.text.trim().toLowerCase();
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);

    if (name.isEmpty ||
        newUsername.isEmpty ||
        day == null ||
        month == null ||
        year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm alanları doldurunuz.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      final data = doc.data() as Map<String, dynamic>;
      final currentUsername = data['username'] ?? '';

      Map<String, dynamic> updates = {
        'fullName': name,
        'birthDate': Timestamp.fromDate(DateTime(year, month, day)),
        'display_preference': _displayPreference,
      };

      if (newUsername != currentUsername) {
        // Cooldown check: 15 minutes
        if (_usernameLastChanged != null) {
          final diff = DateTime.now().difference(_usernameLastChanged!);
          if (diff.inMinutes < 15) {
            final remaining = 15 - diff.inMinutes;
            throw Exception('cooldown:$remaining');
          }
        }

        // Uniqueness check
        final query = await _firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();
        if (query.docs.isNotEmpty) {
          throw Exception('username-taken');
        }

        updates['username'] = newUsername;
        updates['username_last_changed'] = FieldValue.serverTimestamp();
      }

      await userRef.update(updates);
      await _loadUserData(); // Refresh local state

      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
      }
    } catch (e) {
      String msg = 'Hata oluştu.';
      if (e.toString().contains('username-taken')) {
        msg = 'Bu kullanıcı adı zaten alınmış.';
      } else if (e.toString().contains('cooldown')) {
        final parts = e.toString().split(':');
        final rem = parts.length > 1 ? parts[1] : '?';
        msg =
            'Kullanıcı adınızı değiştirmek için lütfen $rem dakika daha bekleyin.';
      } else if (e.toString().contains('network')) {
        msg = 'Bağlantı hatası, lütfen internetinizi kontrol edin.';
      }
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
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
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
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
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: 'İsim Soyisim düzenleme alanı',
                      child: TextField(
                        controller: _fullNameController,
                        decoration:
                            const InputDecoration(labelText: 'İsim Soyisim'),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'Kullanıcı Adı düzenleme alanı',
                      hint: '15 dakikada bir değiştirilebilir',
                      child: TextField(
                        controller: _usernameController,
                        decoration:
                            const InputDecoration(labelText: 'Kullanıcı Adı'),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Platformda nasıl görünmek istersiniz?',
                        style: TextStyle(color: Colors.cyan, fontSize: 18)),
                    Semantics(
                      label: 'Platform görünüm seçimi açılır menüsü',
                      child: DropdownButton<String>(
                        value: _displayPreference,
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style:
                            const TextStyle(color: Colors.yellow, fontSize: 20),
                        items: const [
                          DropdownMenuItem(
                              value: 'fullName', child: Text('İsim Soyisim')),
                          DropdownMenuItem(
                              value: 'username', child: Text('Kullanıcı Adı')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _displayPreference = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Doğum Tarihi',
                        style: TextStyle(color: Colors.cyan, fontSize: 18)),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Gün giriniz',
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
                            label: 'Ay giriniz',
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
                            label: 'Yıl giriniz',
                            child: TextFormField(
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Yıl'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Semantics(
                      label: 'Bilgileri Kaydet butonu',
                      button: true,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Bilgileri Kaydet'),
                      ),
                    ),
                    const Divider(height: 60, color: Colors.cyan, thickness: 2),
                    Semantics(
                      label: 'Şifre Değiştirme panelini açma butonu',
                      button: true,
                      child: TextButton.icon(
                        onPressed: () => setState(
                            () => _showPasswordFields = !_showPasswordFields),
                        icon: Icon(
                            _showPasswordFields
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.yellow),
                        label: const Text('Şifre Değiştir',
                            style:
                                TextStyle(color: Colors.yellow, fontSize: 20)),
                      ),
                    ),
                    if (_showPasswordFields) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        label: 'Yeni Şifre alanı',
                        child: TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Yeni Şifre'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: 'Yeni Şifre Tekrar alanı',
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Yeni Şifre Tekrar'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        label: 'Şifreyi Güncelle butonu',
                        button: true,
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan),
                          child: const Text('Şifreyi Güncelle',
                              style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
