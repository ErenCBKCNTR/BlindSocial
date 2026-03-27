import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showPasswordFields = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _displayPreference = 'username';
  DateTime? _usernameLastChanged;
  String _appVersion = '';

  String? _voiceBioUrl;
  bool _isRecordingBio = false;
  bool _isPlayingBio = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  Timer? _recordTimer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingBio = false);
    });
    _loadUserData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
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
        _voiceBioUrl = data['voiceBioUrl'];
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _recordVoiceBio() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_bio.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 22050),
          path: path,
        );

        setState(() {
          _isRecordingBio = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          setState(() => _recordDuration++);
          if (_recordDuration >= 15) {
            await _stopRecordingBio();
          }
        });
      }
    } catch (e) {
      debugPrint('Bio record start error: $e');
    }
  }

  Future<void> _stopRecordingBio() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecordingBio = false);

    if (path != null && File(path).existsSync()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        final ref = FirebaseStorage.instance
            .ref()
            .child('voice_bios')
            .child('${user.uid}_bio.m4a');

        await ref.putFile(File(path));
        final url = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'voiceBioUrl': url});

        if (mounted) {
          setState(() {
            _voiceBioUrl = url;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli kartvizitiniz kaydedildi.')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli kartvizit yüklenirken hata oluştu.')));
        }
      }
    }
  }

  Future<void> _playVoiceBio() async {
    if (_voiceBioUrl == null) return;
    if (_isPlayingBio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingBio = false);
    } else {
      await _audioPlayer.play(UrlSource(_voiceBioUrl!));
      setState(() => _isPlayingBio = true);
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
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
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
        final query = await FirebaseFirestore.instance
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
                    const Divider(height: 30, color: Colors.cyan, thickness: 2),
                    const Text('Sesli Kendini Tanıtma (Maks 15 sn)',
                        style: TextStyle(color: Colors.cyan, fontSize: 18)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_voiceBioUrl != null)
                          Semantics(
                            label: 'Sesli kartvizitimi dinle',
                            button: true,
                            child: IconButton(
                              icon: Icon(
                                _isPlayingBio ? Icons.stop_circle : Icons.play_circle_fill,
                                color: Colors.yellow,
                                size: 48,
                              ),
                              onPressed: _playVoiceBio,
                              tooltip: _isPlayingBio ? 'Durdur' : 'Sesli biyografiyi dinle',
                            ),
                          ),
                        const SizedBox(width: 20),
                        Semantics(
                          label: 'Sesli kartvizit kaydet veya değiştir',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              _isRecordingBio ? Icons.stop_circle : Icons.mic,
                              color: _isRecordingBio ? Colors.red : Colors.cyan,
                              size: 48,
                            ),
                            onPressed: _isRecordingBio ? _stopRecordingBio : _recordVoiceBio,
                            tooltip: _isRecordingBio ? 'Kaydı Durdur' : 'Yeni sesli biyografi kaydet',
                          ),
                        ),
                      ],
                    ),
                    if (_isRecordingBio)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Kaydediliyor... $_recordDuration sn',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
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
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            labelText: 'Yeni Şifre',
                            suffixIcon: Semantics(
                              label: _obscureNewPassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                              button: true,
                              child: IconButton(
                                icon: Icon(
                                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.cyan,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: 'Yeni Şifre Tekrar alanı',
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Yeni Şifre Tekrar',
                            suffixIcon: Semantics(
                              label: _obscureConfirmPassword ? 'Şifreyi göster' : 'Şifreyi gizle',
                              button: true,
                              child: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.cyan,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
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
                    Center(
                      child: Semantics(
                        label: 'Uygulama versiyonu: $_appVersion',
                        child: Text(
                          'Versiyon: $_appVersion',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
