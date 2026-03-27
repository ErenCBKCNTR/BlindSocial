import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'chat_screen.dart';

class ChatRoomsScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const ChatRoomsScreen({super.key, this.auth, this.firestore});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  bool _isProfileIncomplete = false;
  int? _userRole;

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    bool isIncomplete = false;
    if (!doc.exists) {
      isIncomplete = true;
    } else {
      final data = doc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _userRole = data['role_id'] as int?;
        });
      }

      if ((data['fullName'] ?? '').isEmpty ||
          (data['username'] ?? '').isEmpty ||
          data['birthDate'] == null) {
        isIncomplete = true;
      }
    }

    if (isIncomplete) {
      setState(() => _isProfileIncomplete = true);
      if (mounted) {
        _showIncompleteProfileDialog();
      }
    }
  }

  void _showIncompleteProfileDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final dayController = TextEditingController();
    final monthController = TextEditingController();
    final yearController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (context) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Profil Tamamlama Gerekli',
                    style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'İsim Soyisim giriş alanı',
                    hint: 'Tam adınızı giriniz',
                    child: TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'İsim Soyisim'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label: 'Kullanıcı Adı giriş alanı',
                    hint: 'Benzersiz bir kullanıcı adı seçiniz',
                    child: TextField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Doğum Tarihi',
                        style: TextStyle(color: Colors.cyan, fontSize: 18)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Doğum günü',
                          hint: 'Gün giriniz (2 haneli)',
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Gün'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          label: 'Doğum ayı',
                          hint: 'Ay giriniz (2 haneli)',
                          child: TextField(
                            controller: monthController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Ay'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          label: 'Doğum yılı',
                          hint: 'Yıl giriniz (4 haneli)',
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Yıl'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  isSaving
                      ? const CircularProgressIndicator()
                      : Semantics(
                          label: 'Bilgileri Kaydet butonu',
                          button: true,
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final username =
                                  usernameController.text.trim().toLowerCase();
                              final d = int.tryParse(dayController.text);
                              final m = int.tryParse(monthController.text);
                              final y = int.tryParse(yearController.text);

                              if (name.isEmpty ||
                                  username.isEmpty ||
                                  d == null ||
                                  m == null ||
                                  y == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Lütfen tüm alanları doldurun.')),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              try {
                                // Check username uniqueness
                                final userQuery = await _firestore
                                    .collection('users')
                                    .where('username', isEqualTo: username)
                                    .get();

                                if (userQuery.docs.isNotEmpty &&
                                    userQuery.docs.first.id !=
                                        _auth.currentUser?.uid) {
                                  throw Exception('username-taken');
                                }

                                final birthDate = DateTime(y, m, d);

                                await _firestore
                                    .collection('users')
                                    .doc(_auth.currentUser?.uid)
                                    .set({
                                  'fullName': name,
                                  'username': username,
                                  'birthDate': Timestamp.fromDate(birthDate),
                                  'role_id': 2,
                                  'display_preference': 'username',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                                if (mounted) {
                                  // ignore: use_build_context_synchronously
                                  Navigator.pop(context);
                                  setState(() => _isProfileIncomplete = false);
                                }
                              } catch (e) {
                                if (!mounted) return;
                                String msg = 'Hata oluştu.';
                                if (e.toString().contains('username-taken')) {
                                  msg = 'Bu kullanıcı adı zaten alınmış.';
                                } else if (e.toString().contains('network')) {
                                  msg = 'Bağlantı hatası, lütfen internetinizi kontrol edin.';
                                }
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(msg)));
                              } finally {
                                if (mounted) setModalState(() => isSaving = false);
                              }
                            },
                            child: const Text('Bilgileri Kaydet'),
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditRoomDialog(DocumentSnapshot roomDoc) {
    final roomData = roomDoc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: roomData['name']);
    final capacityController =
        TextEditingController(text: roomData['maxCapacity']?.toString());
    final passwordController = TextEditingController(text: roomData['password']);
    String ttlPreference = roomData['ttlPreference'] ?? '24h';

    showDialog(
      context: context,
      builder: (context) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text('Odayı Düzenle', style: TextStyle(color: Colors.yellow)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Oda İsmi', labelStyle: TextStyle(color: Colors.cyan)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Kapasite', labelStyle: TextStyle(color: Colors.cyan)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre (Boş = Şifresiz)',
                        labelStyle: const TextStyle(color: Colors.cyan),
                        suffixIcon: Semantics(
                          label: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                              color: Colors.cyan,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscure = !obscure;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Mesaj Saklanma Süresi',
                        style: TextStyle(color: Colors.cyan, fontSize: 18)),
                    Semantics(
                      label: 'Mesaj Saklanma Süresi seçimi',
                      child: DropdownButton<String>(
                        value: ttlPreference,
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.yellow, fontSize: 20),
                        items: const [
                          DropdownMenuItem(value: '24h', child: Text('24 Saat')),
                          DropdownMenuItem(value: '3d', child: Text('3 Gün')),
                          DropdownMenuItem(value: '7d', child: Text('7 Gün')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => ttlPreference = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal')),
                ElevatedButton(
                  onPressed: () async {
                    int maxCap = int.tryParse(capacityController.text) ?? 10;

                    int ttlHours = 24;
                    if (ttlPreference == '3d') ttlHours = 72;
                    if (ttlPreference == '7d') ttlHours = 168;

                    await roomDoc.reference.update({
                      'name': nameController.text.trim(),
                      'maxCapacity': maxCap,
                      'password': passwordController.text.isEmpty
                          ? null
                          : _hashPassword(passwordController.text),
                      'ttlPreference': ttlPreference,
                      'ttl': ttlHours,
                    });
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  },
                  child: const Text('Güncelle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '10');
    final passwordController = TextEditingController();
    String ttlPreference = '24h';
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.black,
          title: Semantics(
            label: 'Yeni Oda Oluştur',
            child: const Text('Yeni Oda Oluştur',
                style: TextStyle(color: Colors.yellow)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Oda İsmi Giriş Alanı',
                  child: TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: const InputDecoration(
                      labelText: 'Oda İsmi',
                      labelStyle: TextStyle(color: Colors.cyan),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Kapasite Giriş Alanı',
                  hint: 'Maksimum katılımcı sayısı',
                  child: TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: const InputDecoration(
                      labelText: 'Kapasite (Örn: 10)',
                      labelStyle: TextStyle(color: Colors.cyan),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: 'Şifre Giriş Alanı',
                  hint: 'Oda şifreli olsun istiyorsanız doldurun, yoksa boş bırakın',
                  child: TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Şifre (Opsiyonel)',
                      labelStyle: const TextStyle(color: Colors.cyan),
                      enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyan)),
                      suffixIcon: Semantics(
                        label: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                            color: Colors.cyan,
                          ),
                          onPressed: () {
                            setModalState(() {
                              obscure = !obscure;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Mesaj Saklanma Süresi',
                    style: TextStyle(color: Colors.cyan, fontSize: 18)),
                Semantics(
                  label: 'Mesaj Saklanma Süresi seçimi',
                  child: DropdownButton<String>(
                    value: ttlPreference,
                    dropdownColor: Colors.black,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.yellow, fontSize: 20),
                    items: const [
                      DropdownMenuItem(value: '24h', child: Text('24 Saat')),
                      DropdownMenuItem(value: '3d', child: Text('3 Gün')),
                      DropdownMenuItem(value: '7d', child: Text('7 Gün')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => ttlPreference = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Semantics(
                label: 'Vazgeç butonu',
                child: const Text('İptal',
                    style: TextStyle(color: Colors.red, fontSize: 18)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final user = _auth.currentUser;
                if (user == null) return;

                // Generate a random 6-digit numericId
                final random = math.Random();
                final numericId = 100000 + random.nextInt(900000);

                await _firestore.collection('chat_rooms').add({
                  'name': nameController.text.trim(),
                  'numericId': numericId,
                  'maxCapacity': int.tryParse(capacityController.text) ?? 10,
                  'password': passwordController.text.isEmpty
                      ? null
                      : _hashPassword(passwordController.text),
                  'plainPassword': passwordController.text.isEmpty ? null : passwordController.text,
                  'ttl': ttlPreference,
                  'creatorId': user.uid,
                  'currentParticipants': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: Semantics(
                label: 'Oda Oluştur butonu',
                child: const Text('Oluştur',
                    style: TextStyle(color: Colors.black, fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Sohbet Odaları Başlığı',
          child: const Text('Sohbet Odaları'),
        ),
        leading: _isProfileIncomplete
          ? null
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 30),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menüyü Aç',
              ),
            ),
        actions: [
          Semantics(
            label: 'Oturumu kapat',
            hint: 'Giriş ekranına geri dönmek için dokunun',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout, size: 30),
              onPressed: () async {
                await _auth.signOut();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ),
        ],
      ),
      drawer: _isProfileIncomplete ? null : Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.yellow),
              child: Text(
                'Blind Social Menü',
                style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            Semantics(
              label: 'Sesli Odalar butonu',
              button: true,
              child: ListTile(
                leading: const Icon(Icons.forum, color: Colors.cyan, size: 30),
                title: const Text('Sesli Odalar', style: TextStyle(color: Colors.white, fontSize: 22)),
                onTap: () => Navigator.pop(context),
              ),
            ),
            Semantics(
              label: 'BS Meydan butonu',
              button: true,
              child: ListTile(
                leading: const Icon(Icons.public, color: Colors.cyan, size: 30),
                title: const Text('BS Meydan', style: TextStyle(color: Colors.white, fontSize: 22)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/square');
                },
              ),
            ),
            Semantics(
              label: 'Hesabım butonu',
              button: true,
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.cyan, size: 30),
                title: const Text('Hesabım', style: TextStyle(color: Colors.white, fontSize: 22)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
            ),
            if (_userRole == 0)
              Semantics(
                label: 'Yönetici Paneli butonu',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.cyan, size: 30),
                  title: const Text('Yönetici Paneli', style: TextStyle(color: Colors.white, fontSize: 22)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin_panel');
                  },
                ),
              ),
            if (_userRole == 1)
              Semantics(
                label: 'Yetkili Menüsü butonu',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.build, color: Colors.cyan, size: 30),
                  title: const Text('Yetkili Menüsü', style: TextStyle(color: Colors.white, fontSize: 22)),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.black,
                        title: const Row(
                          children: [
                            Icon(Icons.construction, color: Colors.yellow),
                            SizedBox(width: 10),
                            Text('Uyarı', style: TextStyle(color: Colors.yellow)),
                          ],
                        ),
                        content: const Text('Bu bölüm yapım aşamasındadır.', style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tamam', style: TextStyle(color: Colors.cyan)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isProfileIncomplete ? null : Semantics(
        label: 'Yeni Oda Oluştur butonu',
        hint: 'Yeni bir sohbet odası başlatmak için dokunun',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: _showCreateRoomDialog,
          backgroundColor: Colors.yellow,
          icon: const Icon(Icons.add, color: Colors.black, size: 30),
          label: const Text('Oda Oluştur',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isProfileIncomplete
        ? Container(color: Colors.black, child: const Center(child: Text('Lütfen profilinizi tamamlayın', style: TextStyle(color: Colors.white, fontSize: 20))))
        : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chat_rooms')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Semantics(
                label: 'Bir hata oluştu: ${snapshot.error}',
                child: Text(
                  'Bir hata oluştu.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Semantics(
                label: 'Sohbet odaları yükleniyor, lütfen bekleyin',
                child: const CircularProgressIndicator(strokeWidth: 6),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Henüz aktif sunucu veya oda bulunmuyor.',
                    child: Column(
                      children: [
                        const Icon(Icons.forum, size: 100, color: Colors.yellow),
                        const SizedBox(height: 20),
                        Text(
                          'Henüz bir sohbet odası bulunmuyor.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var room = snapshot.data!.docs[index];
              var roomData = room.data() as Map<String, dynamic>;
              var roomName = roomData['name'] ?? 'İsimsiz Oda';
              var roomId = room.id;
              var maxCapacity = roomData['maxCapacity'] ?? 10;
              var currentParticipants = roomData['currentParticipants'] ?? 0;
              var isLocked =
                  roomData['password'] != null && roomData['password'] != '';
              var isCreator = roomData['creatorId'] == _auth.currentUser?.uid;

              String semanticLabel = '$roomName sohbet odası. '
                  'Kapasite: $currentParticipants bölü $maxCapacity. '
                  '${isLocked ? "Şifreli oda." : "Açık oda."} '
                  'Odaya girmek için iki kez dokunun.';

              return Semantics(
                label: semanticLabel,
                button: true,
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const Icon(Icons.meeting_room,
                          color: Colors.cyan, size: 40),
                      if (isLocked && !isCreator)
                        const Icon(Icons.lock, color: Colors.yellow, size: 20),
                    ],
                  ),
                  title: Text(
                    roomName,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    'Kapasite: $currentParticipants / $maxCapacity',
                    style: const TextStyle(color: Colors.cyan, fontSize: 18),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roomData['creatorId'] == _auth.currentUser?.uid)
                        Semantics(
                          label: 'Odayı Düzenle',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.cyan),
                            onPressed: () => _showEditRoomDialog(room),
                          ),
                        ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.yellow),
                    ],
                  ),
                  onTap: () async {
                    // Check capacity
                    if (currentParticipants >= maxCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Oda dolu, lütfen başka bir odayı deneyin.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Handle password
                    if (isLocked && !isCreator) {
                      final passwordController = TextEditingController();
                      final correctPassword = roomData['password'];

                      bool? success = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          bool obscure = true;
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              return AlertDialog(
                                backgroundColor: Colors.black,
                                title: const Text('Şifre Gerekli', style: TextStyle(color: Colors.yellow)),
                                content: TextField(
                                  controller: passwordController,
                                  obscureText: obscure,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Oda Şifresi',
                                    labelStyle: const TextStyle(color: Colors.cyan),
                                    suffixIcon: Semantics(
                                      label: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                                      button: true,
                                      child: IconButton(
                                        icon: Icon(
                                          obscure ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.cyan,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            obscure = !obscure;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_hashPassword(passwordController.text) == correctPassword) {
                                        Navigator.pop(context, true);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Hatalı Şifre')),
                                        );
                                      }
                                    },
                                    child: const Text('Giriş'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );

                      if (success != true) return;
                    }

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            roomId: roomId,
                            roomName: roomName,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
