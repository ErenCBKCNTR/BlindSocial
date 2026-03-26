import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isProfileIncomplete = false;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    bool isIncomplete = false;
    if (!doc.exists) {
      isIncomplete = true;
    } else {
      final data = doc.data() as Map<String, dynamic>;
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
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.black,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profil Tamamlama Gerekli',
                style: TextStyle(color: Colors.yellow, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lütfen eksik bilgilerinizi doldurunuz. İsim, kullanıcı adı ve doğum tarihi alanları zorunludur.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
                child: const Text('Profilime Git'),
              ),
            ],
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Yeni Şifre (Boş = Şifresiz)',
                    labelStyle: TextStyle(color: Colors.cyan)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await roomDoc.reference.update({
                'name': nameController.text.trim(),
                'maxCapacity': int.tryParse(capacityController.text) ?? 10,
                'password': passwordController.text.isEmpty
                    ? null
                    : passwordController.text,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '10');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'Şifre (Opsiyonel)',
                    labelStyle: TextStyle(color: Colors.cyan),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan)),
                  ),
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

              await FirebaseFirestore.instance.collection('chat_rooms').add({
                'name': nameController.text.trim(),
                'maxCapacity': int.tryParse(capacityController.text) ?? 10,
                'password': passwordController.text.isEmpty
                    ? null
                    : passwordController.text,
                'creatorId': user.uid,
                'currentParticipants': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
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
            label: 'Çıkış Yap butonu',
            hint: 'Giriş ekranına geri dönmek için dokunun',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout, size: 30),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
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
        stream: FirebaseFirestore.instance
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
              var isLocked = roomData['password'] != null;

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
                      if (isLocked)
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
                    if (isLocked) {
                      final passwordController = TextEditingController();
                      final correctPassword = roomData['password'];

                      bool? success = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.black,
                          title: const Text('Şifre Gerekli', style: TextStyle(color: Colors.yellow)),
                          content: TextField(
                            controller: passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Oda Şifresi',
                              labelStyle: TextStyle(color: Colors.cyan),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                            ElevatedButton(
                              onPressed: () {
                                if (passwordController.text == correctPassword) {
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
                        ),
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
