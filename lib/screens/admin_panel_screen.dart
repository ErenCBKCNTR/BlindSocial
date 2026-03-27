import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const AdminPanelScreen({super.key, this.firestore});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late final FirebaseFirestore _firestore;
  bool _filterRoomsWithPassword = false;
  bool _filterRoomsWithoutPassword = false;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
  }

  Widget _buildMemberList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Colors.white)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Üye bulunamadı.', style: TextStyle(color: Colors.white)));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String userId = user['numericId']?.toString() ?? 'Bilinmiyor';
            String username = user['username'] ?? 'İsimsiz';

            Timestamp? createdAtTimestamp = user['createdAt'] as Timestamp?;
            String createdAt = createdAtTimestamp != null
                ? "${createdAtTimestamp.toDate().day}/${createdAtTimestamp.toDate().month}/${createdAtTimestamp.toDate().year}"
                : "Bilinmiyor";

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(
                  'ID: $userId - $username',
                  style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kayıt Tarihi: $createdAt',
                  style: const TextStyle(color: Colors.cyan),
                ),
                trailing: Semantics(
                  label: 'Detaylı bilgileri gör',
                  button: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                    onPressed: () => _showUserDetails(context, user),
                    child: const Text('Detaylar', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) {
    Timestamp? birthTimestamp = user['birthDate'] as Timestamp?;
    String birthDate = birthTimestamp != null
        ? "${birthTimestamp.toDate().day}/${birthTimestamp.toDate().month}/${birthTimestamp.toDate().year}"
        : "Bilinmiyor";

    Timestamp? createdAtTimestamp = user['createdAt'] as Timestamp?;
    String createdAt = createdAtTimestamp != null
        ? "${createdAtTimestamp.toDate().day}/${createdAtTimestamp.toDate().month}/${createdAtTimestamp.toDate().year}"
        : "Bilinmiyor";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text('${user['username'] ?? 'Bilinmiyor'} Detayları', style: const TextStyle(color: Colors.yellow)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('İsim Soyisim: ${user['fullName'] ?? 'Bilinmiyor'}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                Text('Kayıt Tarihi: $createdAt', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                Text('E-posta: ${user['email'] ?? 'Bilinmiyor'}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                Text('Doğum Tarihi: $birthDate', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Kapat', style: TextStyle(color: Colors.cyan)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilterChip(
                label: const Text('Şifreli', style: TextStyle(color: Colors.white)),
                selected: _filterRoomsWithPassword,
                selectedColor: Colors.cyan.withValues(alpha: 0.5),
                backgroundColor: Colors.grey[800],
                onSelected: (bool value) {
                  setState(() {
                    _filterRoomsWithPassword = value;
                    if (value) _filterRoomsWithoutPassword = false;
                  });
                },
              ),
              FilterChip(
                label: const Text('Şifresiz', style: TextStyle(color: Colors.white)),
                selected: _filterRoomsWithoutPassword,
                selectedColor: Colors.cyan.withValues(alpha: 0.5),
                backgroundColor: Colors.grey[800],
                onSelected: (bool value) {
                  setState(() {
                    _filterRoomsWithoutPassword = value;
                    if (value) _filterRoomsWithPassword = false;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chat_rooms').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Colors.white)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs;

              if (_filterRoomsWithPassword) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['plainPassword'] != null && data['plainPassword'].toString().isNotEmpty;
                }).toList();
              } else if (_filterRoomsWithoutPassword) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['plainPassword'] == null || data['plainPassword'].toString().isEmpty;
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(child: Text('Oda bulunamadı.', style: TextStyle(color: Colors.white)));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var room = docs[index].data() as Map<String, dynamic>;
                  String roomId = room['numericId']?.toString() ?? 'Bilinmiyor';
                  String roomName = room['name'] ?? 'İsimsiz Oda';
                  String password = room['plainPassword'] ?? 'Şifresiz';

                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text(
                        'ID: $roomId - $roomName',
                        style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Şifre: $password',
                        style: const TextStyle(color: Colors.cyan),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            label: 'Yönetici Paneli Başlığı',
            child: const Text('Yönetici Paneli', style: TextStyle(color: Colors.yellow)),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.yellow,
            labelColor: Colors.yellow,
            unselectedLabelColor: Colors.cyan,
            tabs: [
              Tab(
                icon: Icon(Icons.meeting_room),
                text: 'Oda Listesi',
              ),
              Tab(
                icon: Icon(Icons.people),
                text: 'Üyeler',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Oda Listesi
            _buildRoomList(),
            // Üyeler
            _buildMemberList(),
          ],
        ),
      ),
    );
  }
}
