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
          return Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Üye bulunamadı.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
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
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kayıt Tarihi: $createdAt',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
                trailing: Semantics(
                  label: 'Detaylı bilgileri gör',
                  button: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                    onPressed: () => _showUserDetails(context, user),
                    child: Text('Detaylar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text('${user['username'] ?? 'Bilinmiyor'} Detayları', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('İsim Soyisim: ${user['fullName'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: 10),
                Text('Kayıt Tarihi: $createdAt', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: 10),
                Text('E-posta: ${user['email'] ?? 'Bilinmiyor'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: 10),
                Text('Doğum Tarihi: $birthDate', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Kapat', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
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
                label: Text('Şifreli', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                selected: _filterRoomsWithPassword,
                selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                backgroundColor: Colors.grey[800],
                onSelected: (bool value) {
                  setState(() {
                    _filterRoomsWithPassword = value;
                    if (value) _filterRoomsWithoutPassword = false;
                  });
                },
              ),
              FilterChip(
                label: Text('Şifresiz', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                selected: _filterRoomsWithoutPassword,
                selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
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
                return Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
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
                return Center(child: Text('Oda bulunamadı.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
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
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Şifre: $password',
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
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
            child: Text('Yönetici Paneli', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.secondary,
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
