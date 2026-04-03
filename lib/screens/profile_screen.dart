import 'package:flutter/material.dart';
import 'dart:ui' show TextDirection;
import 'package:flutter/semantics.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/theme_notifier.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Şu anda Hesabım sayfasındasınız"),
            duration: const Duration(seconds: 2),
          ),
        );
        SemanticsService.announce("Şu anda Hesabım sayfasındasınız", TextDirection.ltr);
      }
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

  String _originalFullName = '';
  String _originalUsername = '';
  String _originalDisplayPreference = '';
  int? _originalDay;
  int? _originalMonth;
  int? _originalYear;

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _fullNameController.text = data['fullName'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _displayPreference = data['display_preference'] ?? 'username';

        _originalFullName = _fullNameController.text;
        _originalUsername = _usernameController.text;
        _originalDisplayPreference = _displayPreference;

        if (data['username_last_changed'] != null) {
          _usernameLastChanged = (data['username_last_changed'] as Timestamp)
              .toDate();
        }
        if (data['birthDate'] != null) {
          final date = (data['birthDate'] as Timestamp).toDate();
          _dayController.text = date.day.toString();
          _monthController.text = date.month.toString();
          _yearController.text = date.year.toString();

          _originalDay = date.day;
          _originalMonth = date.month;
          _originalYear = date.year;
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
        const SnackBar(content: Text('Lütfen tüm alanları doldurunuz.')),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(newUsername)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı boşluk içeremez. Sadece harf, rakam, nokta ve alt çizgi kullanılabilir.'),
        ),
      );
      return;
    }

    if (name == _originalFullName &&
        newUsername == _originalUsername &&
        _displayPreference == _originalDisplayPreference &&
        day == _originalDay &&
        month == _originalMonth &&
        year == _originalYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncellenen değişiklik bulunamadı.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
      }
    } catch (e) {
      String msg = 'Hata oluştu.';
      if (e.toString().contains('username-taken')) {
        msg = 'Bu kullanıcı adı zaten alınmış.';
      } else if (e.toString().contains('cooldown:')) {
        final regex = RegExp(r'cooldown:(\d+)m(\d+)s');
        final match = regex.firstMatch(e.toString());
        if (match != null) {
          final m = match.group(1);
          final s = match.group(2);
          msg = 'Kullanıcı adınızı değiştirmek için $m dakika $s saniye beklemeniz gerekmektedir.';
        } else {
          msg = 'Kullanıcı adınızı değiştirmek için biraz beklemeniz gerekmektedir.';
        }
      } else if (e.toString().contains('network')) {
        msg = 'Bağlantı hatası, lütfen internetinizi kontrol edin.';
      }
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifreler eşleşmiyor.')));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('En az 6 karakter olmalı.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.currentUser!.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Hata oluştu.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, child) {
        final themeIndex = appThemeNotifier.currentThemeIndex;

        return Scaffold(
          appBar: themeIndex == 2
              ? null // Use SliverAppBar for Minimalist Theme
              : AppBar(title: Text('Hesabım')),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _buildLayoutForTheme(themeIndex, theme),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildThemeSelector(ThemeData theme) {
    return const SizedBox.shrink();
  }

  Widget _buildLayoutForTheme(int themeIndex, ThemeData theme) {
    if (themeIndex == 2) {
      // Modern Minimalist Theme Layout
      return CustomScrollView(
        key: const ValueKey(2),
        slivers: [
          SliverAppBar(
            expandedHeight: 150.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Hesabım'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildThemeSelector(theme),
                  const SizedBox(height: 30),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            'İsim Soyisim',
                            _fullNameController,
                            'İsim Soyisim düzenleme alanı',
                            maxLength: 50,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            'Kullanıcı Adı',
                            _usernameController,
                            'Kullanıcı Adı düzenleme alanı',
                            hint: '15 dakikada bir değiştirilebilir',
                            maxLength: 20,
                          ),
                          const SizedBox(height: 20),
                          _buildDropdown(theme),
                          const SizedBox(height: 20),
                          _buildDateFields(theme),
                          const SizedBox(height: 30),
                          _buildSaveButton(theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildPasswordSection(theme),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildVersionText(theme),
                  const SizedBox(height: 20),
                  _buildLogoutButton(theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (themeIndex == 1) {
      // Neon Cyberpunk Theme Layout
      return SingleChildScrollView(
        key: const ValueKey(1),
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SYSTEM CONFIG',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: AppFonts.size(24)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _buildThemeSelector(theme),
              const SizedBox(height: 30),
              _buildTextField(
                'İsim Soyisim',
                _fullNameController,
                'İsim Soyisim düzenleme alanı',
                maxLength: 50,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Kullanıcı Adı',
                _usernameController,
                'Kullanıcı Adı düzenleme alanı',
                hint: '15 dakikada bir değiştirilebilir',
                maxLength: 20,
              ),
              const SizedBox(height: 20),
              _buildDropdown(theme),
              const SizedBox(height: 20),
              _buildDateFields(theme),
              const SizedBox(height: 30),
              _buildSaveButton(theme),
              const Divider(height: 60, thickness: 2),
              _buildPasswordSection(theme),
              const SizedBox(height: 40),
              _buildLogoutButton(theme),
              const SizedBox(height: 20),
              _buildVersionText(theme),
            ],
          ),
        ),
      );
    } else {
      // High Contrast Theme Layout (Original Style)
      return SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThemeSelector(theme),
            const SizedBox(height: 30),
            _buildTextField(
              'İsim Soyisim',
              _fullNameController,
              'İsim Soyisim düzenleme alanı',
              maxLength: 50,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'Kullanıcı Adı',
              _usernameController,
              'Kullanıcı Adı düzenleme alanı',
              hint: '15 dakikada bir değiştirilebilir',
              maxLength: 20,
            ),
            const SizedBox(height: 20),
            _buildDropdown(theme),
            const SizedBox(height: 20),
            _buildDateFields(theme),
            const SizedBox(height: 30),
            _buildSaveButton(theme),
            const Divider(height: 60, thickness: 2),
            _buildPasswordSection(theme),
            const SizedBox(height: 40),
            _buildLogoutButton(theme),
            const SizedBox(height: 20),
            _buildVersionText(theme),
            const SizedBox(height: 20),
          ],
        ),
      );
    }
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () async {
        await _auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      },
      icon: const Icon(Icons.logout),
      label: Text(
        'Oturumu Kapat',
        style: TextStyle(fontSize: AppFonts.size(20), fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String semanticLabel, {
    String? hint,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: AppFonts.size(20),
      ),
    );
  }

  Widget _buildDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Platformda nasıl görünmek istersiniz?',
          style: TextStyle(color: theme.colorScheme.secondary, fontSize: AppFonts.size(18)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _displayPreference == 'fullName'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  foregroundColor: _displayPreference == 'fullName'
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                onPressed: () {
                  setState(() => _displayPreference = 'fullName');
                },
                child: const Text('İsim Soyisim', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _displayPreference == 'username'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  foregroundColor: _displayPreference == 'username'
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                onPressed: () {
                  setState(() => _displayPreference = 'username');
                },
                child: const Text('Kullanıcı Adı', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Doğum Tarihi',
          style: TextStyle(color: theme.colorScheme.secondary, fontSize: AppFonts.size(18)),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Gün'),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _monthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Ay'),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Yıl'),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _updateProfile,
      child: const Text('Bilgileri Kaydet'),
    );
  }

  Widget _buildPasswordSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () =>
              setState(() => _showPasswordFields = !_showPasswordFields),
          icon: Icon(
            _showPasswordFields ? Icons.expand_less : Icons.expand_more,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'Şifre Değiştir',
            style: TextStyle(color: theme.colorScheme.primary, fontSize: AppFonts.size(20)),
          ),
        ),
        if (_showPasswordFields) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'Yeni Şifre',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  color: theme.colorScheme.secondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Yeni Şifre Tekrar',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: theme.colorScheme.secondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
            ),
            child: Text(
              'Şifreyi Güncelle',
              style: TextStyle(color: theme.colorScheme.onSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVersionText(ThemeData theme) {
    return Center(
      child: Text(
        'Versiyon: $_appVersion',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: AppFonts.size(14),
        ),
      ),
    );
  }
}
