import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel_room_details.dart';
import 'admin_panel_user_details.dart';

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

  late final Stream<QuerySnapshot> _usersStream;
  late final Stream<QuerySnapshot> _roomsStream;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    // ⚡ Bolt: Cache Firestore streams in initState rather than build() to prevent
    // re-subscribing and fetching all historical documents on every widget rebuild
    // (e.g., when toggling room filters).
    _usersStream = _firestore.collection('users').orderBy('createdAt', descending: true).snapshots();
    _roomsStream = _firestore.collection('chat_rooms').orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildMemberList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
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
                  'ID: U$userId - $username',
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AdminPanelUserDetails(user: user)),
                      );
                    },
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
            stream: _roomsStream,
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
                        'ID: R$roomId - $roomName',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Şifre: $password',
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                      trailing: Semantics(
                        label: 'Oda detaylarını gör',
                        button: true,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AdminPanelRoomDetails(room: room, roomRef: docs[index].reference),
                              ),
                            );
                          },
                          child: Text('Detaylar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                        ),
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
