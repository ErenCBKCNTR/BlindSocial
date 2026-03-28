import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel_room_details.dart';

class AdminPanelRoomsList extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const AdminPanelRoomsList({super.key, this.firestore});

  @override
  State<AdminPanelRoomsList> createState() => _AdminPanelRoomsListState();
}

class _AdminPanelRoomsListState extends State<AdminPanelRoomsList> {
  late final FirebaseFirestore _firestore;
  bool _filterRoomsWithPassword = false;
  bool _filterRoomsWithoutPassword = false;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odalar')),
      body: Column(
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
                if (snapshot.hasError) return Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

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

                if (docs.isEmpty) return Center(child: Text('Oda bulunamadı.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));

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
                        title: Text('ID: R$roomId - $roomName', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        subtitle: Text('Şifre: $password', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminPanelRoomDetails(room: room, roomRef: docs[index].reference)),
                            );
                          },
                          child: Text('Detaylar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      )
    );
  }
}
