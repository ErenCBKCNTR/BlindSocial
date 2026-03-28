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

  late final Stream<QuerySnapshot> _roomsStream;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    // ⚡ Bolt: Cache Firestore stream in initState rather than build() to prevent
    // re-subscribing and fetching all historical documents on every widget rebuild.
    _roomsStream = _firestore
        .collection('chat_rooms')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    Text(
                      'Profil Tamamlama Gerekli',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'İsim Soyisim',
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı',
                      ),
                    ),
                    SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Doğum Tarihi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(hintText: 'Gün'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: monthController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(hintText: 'Ay'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(hintText: 'Yıl'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    isSaving
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final username = usernameController.text
                                  .trim()
                                  .toLowerCase();
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
                                    content: Text(
                                      'Lütfen tüm alanları doldurun.',
                                    ),
                                  ),
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
                                      'birthDate': Timestamp.fromDate(
                                        birthDate,
                                      ),
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
                                  msg =
                                      'Bağlantı hatası, lütfen internetinizi kontrol edin.';
                                }
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              } finally {
                                if (mounted)
                                  setModalState(() => isSaving = false);
                              }
                            },
                            child: Text('Bilgileri Kaydet'),
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
    final capacityController = TextEditingController(
      text: roomData['maxCapacity']?.toString(),
    );
    final passwordController = TextEditingController(
      text: roomData['password'],
    );
    String ttlPreference = roomData['ttlPreference'] ?? '24h';

    showDialog(
      context: context,
      builder: (context) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(
                'Odayı Düzenle',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Oda İsmi',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Kapasite',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre (Boş = Şifresiz)',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscure = !obscure;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Mesaj Saklanma Süresi',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 18,
                      ),
                    ),
                    DropdownButton<String>(
                      value: ttlPreference,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      isExpanded: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 20,
                      ),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('İptal'),
                ),
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
                          : passwordController.text,
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'Yeni Oda Oluştur',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Oda İsmi',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Kapasite (Örn: 10)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Şifre (Opsiyonel)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      onPressed: () {
                        setModalState(() {
                          obscure = !obscure;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Mesaj Saklanma Süresi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 18,
                  ),
                ),
                DropdownButton<String>(
                  value: ttlPreference,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  isExpanded: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 20,
                  ),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 18,
                ),
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
                      : passwordController.text,
                  'plainPassword': passwordController.text.isEmpty
                      ? null
                      : passwordController.text,
                  'ttl': ttlPreference,
                  'creatorId': user.uid,
                  'currentParticipants': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Oluştur',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 18,
                ),
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
        title: Text('Sohbet Odaları'),
        leading: _isProfileIncomplete
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, size: 30),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menüyü Aç',
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 30),
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      drawer: _isProfileIncomplete
          ? null
          : Drawer(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blind Social Menü',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('users')
                              .where('isOnline', isEqualTo: 1)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final onlineCount = snapshot.data!.docs.length;
                            return Text(
                              'Hasan\nÇevrimiçi kullanıcı sayısı: $onlineCount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.forum,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 30,
                    ),
                    title: Text(
                      'Sesli Odalar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                      ),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.public,
                      color: Colors.cyan,
                      size: 30,
                    ),
                    title: const Text(
                      'BS Meydan',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/square');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.sports_esports,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 30,
                    ),
                    title: Text(
                      'Oyun Odası',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/game_room');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 30,
                    ),
                    title: Text(
                      'Hesabım',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  if (_userRole == 0)
                    ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 30,
                      ),
                      title: Text(
                        'Yönetici Paneli',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/admin_panel');
                      },
                    ),
                  if (_userRole == 1)
                    ListTile(
                      leading: Icon(
                        Icons.build,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 30,
                      ),
                      title: Text(
                        'Yetkili Menüsü',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            title: Row(
                              children: [
                                Icon(
                                  Icons.construction,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Uyarı',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Bu bölüm yapım aşamasındadır.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Tamam',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 20),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 100,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isProfileIncomplete
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateRoomDialog,
              backgroundColor: Theme.of(context).colorScheme.primary,
              icon: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
              label: Text(
                'Oda Oluştur',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: _isProfileIncomplete
          ? Container(
              color: Theme.of(context).colorScheme.onPrimary,
              child: Center(
                child: Text(
                  'Lütfen profilinizi tamamlayın',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _roomsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Bir hata oluştu.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(strokeWidth: 6),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Icon(
                              Icons.forum,
                              size: 100,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Henüz bir sohbet odası bulunmuyor.',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
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
                    var currentParticipants =
                        roomData['currentParticipants'] ?? 0;
                    var isLocked =
                        roomData['password'] != null &&
                        roomData['password'] != '';
                    var isCreator =
                        roomData['creatorId'] == _auth.currentUser?.uid;

                    String semanticLabel =
                        '$roomName sohbet odası. '
                        'Kapasite: $currentParticipants bölü $maxCapacity. '
                        '${isLocked ? "Şifreli oda." : "Açık oda."} '
                        'Odaya girmek için iki kez dokunun.';

                    return ListTile(
                      leading: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Icon(
                            Icons.meeting_room,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 40,
                          ),
                          if (isLocked && !isCreator)
                            Icon(
                              Icons.lock,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                      title: Text(
                        roomName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Kapasite: $currentParticipants / $maxCapacity',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 18,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (roomData['creatorId'] == _auth.currentUser?.uid)
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              onPressed: () => _showEditRoomDialog(room),
                            ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      onTap: () async {
                        // Check capacity
                        if (currentParticipants >= maxCapacity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Oda dolu, lütfen başka bir odayı deneyin.',
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
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
                                    backgroundColor: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    title: Text(
                                      'Şifre Gerekli',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    content: TextField(
                                      controller: passwordController,
                                      obscureText: obscure,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Oda Şifresi',
                                        labelStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            obscure
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              obscure = !obscure;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('İptal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (passwordController.text ==
                                              correctPassword) {
                                            Navigator.pop(context, true);
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Hatalı Şifre'),
                                              ),
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
                    );
                  },
                );
              },
            ),
    );
  }
}
