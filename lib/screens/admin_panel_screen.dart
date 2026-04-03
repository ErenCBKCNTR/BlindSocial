import 'package:flutter/material.dart';
import 'dart:ui' show TextDirection;
import 'package:flutter/semantics.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel_room_details.dart';
import 'admin_panel_user_details.dart';
import 'reported_posts_screen.dart';
import 'bs_bib_call_screen.dart';
import 'release_notes_screen.dart';
import 'online_users_screen.dart';

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
  late final Stream<QuerySnapshot> _bsBibStream;

  late Future<AggregateQuerySnapshot> _onlineUsersCountFuture;
  late Future<AggregateQuerySnapshot> _roomsCountFuture;
  late Future<AggregateQuerySnapshot> _usersCountFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Şu anda Yönetici Paneli sayfasındasınız"),
            duration: const Duration(seconds: 2),
          ),
        );
        SemanticsService.announce("Şu anda Yönetici Paneli sayfasındasınız", TextDirection.ltr);
      }
    });
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    // ⚡ Bolt: Cache Firestore streams in initState rather than build() to prevent
    // re-subscribing and fetching all historical documents on every widget rebuild
    // (e.g., when toggling room filters).
    _usersStream = _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _roomsStream = _firestore
        .collection('chat_rooms')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _bsBibStream = _firestore
        .collection('bs_bib_calls')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _refreshDashboardCounts();
  }

  void _refreshDashboardCounts() {
    setState(() {
      _onlineUsersCountFuture = _firestore.collection('users').where('isOnline', isEqualTo: 1).count().get();
      _roomsCountFuture = _firestore.collection('chat_rooms').count().get();
      _usersCountFuture = _firestore.collection('users').count().get();
    });
  }

  Widget _buildMemberList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Bir hata oluştu.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Üye bulunamadı.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Kayıt Tarihi: $createdAt',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    final userData = Map<String, dynamic>.from(user);
                    userData['id'] = snapshot.data!.docs[index].id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPanelUserDetails(user: userData),
                      ),
                    );
                  },
                  child: Text(
                    'Detaylar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
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
                label: Text(
                  'Şifreli',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                selected: _filterRoomsWithPassword,
                selectedColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.5),
                backgroundColor: Colors.grey[800],
                onSelected: (bool value) {
                  setState(() {
                    _filterRoomsWithPassword = value;
                    if (value) _filterRoomsWithoutPassword = false;
                  });
                },
              ),
              FilterChip(
                label: Text(
                  'Şifresiz',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                selected: _filterRoomsWithoutPassword,
                selectedColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.5),
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
                return Center(
                  child: Text(
                    'Bir hata oluştu.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs;

              if (_filterRoomsWithPassword) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['plainPassword'] != null &&
                      data['plainPassword'].toString().isNotEmpty;
                }).toList();
              } else if (_filterRoomsWithoutPassword) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['plainPassword'] == null ||
                      data['plainPassword'].toString().isEmpty;
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'Oda bulunamadı.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: ListTile(
                      title: Text(
                        'ID: R$roomId - $roomName',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Şifre: $password',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminPanelRoomDetails(
                                room: room,
                                roomRef: docs[index].reference,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Detaylar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
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

  Widget _buildRadioTheaterAdmin() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tiyatro Adı'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Google Drive Paylaşım Linki (mp3/m4a)'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Yeni Tiyatro Ekle'),
                onPressed: () async {
                  if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                    String originalUrl = urlController.text.trim();
                    String finalUrl = originalUrl;

                    // Linkin içinden ID kısmını ayıklar
                    RegExp regExp = RegExp(r"id=([a-zA-Z0-9_-]+)|/d/([a-zA-Z0-9_-]+)");
                    Match? match = regExp.firstMatch(originalUrl);

                    if (match != null) {
                      String fileId = match.group(1) ?? match.group(2)!;
                      finalUrl = "https://drive.google.com/uc?export=download&id=$fileId";
                    }

                    await FirebaseFirestore.instance.collection('radio_theaters').add({
                      'title': titleController.text,
                      'url': finalUrl,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    titleController.clear();
                    urlController.clear();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tiyatro eklendi.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('radio_theaters')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Kayıtlı tiyatro yok.'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title'] ?? ''),
                    subtitle: Text(data['url'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await doc.reference.delete();
                      },
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

  Widget _buildBSBibCallsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _bsBibStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Bir hata oluştu.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var activeDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'active';
        }).toList();

        if (activeDocs.isEmpty) {
          return Center(
            child: Text(
              'Şu an aktif çağrı bulunmuyor',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }

        return ListView.builder(
          itemCount: activeDocs.length,
          itemBuilder: (context, index) {
            var call = activeDocs[index].data() as Map<String, dynamic>;
            String roomId = call['roomId'] ?? 'Bilinmiyor';
            String callerName = call['callerName'] ?? 'İsimsiz';

            Timestamp? createdAtTimestamp = call['createdAt'] as Timestamp?;
            String createdAt = createdAtTimestamp != null
                ? "${createdAtTimestamp.toDate().hour.toString().padLeft(2, '0')}:${createdAtTimestamp.toDate().minute.toString().padLeft(2, '0')}"
                : "Bilinmiyor";

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.videocam, color: Colors.green, size: 40),
                title: Text(
                  'Kullanıcı: $callerName',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Zaman: $createdAt\nOda: $roomId',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BSBibCallScreen(
                          roomId: roomId,
                          isAdmin: true,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Katıl',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Yönetici Paneli',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.secondary,
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Pano'),
              Tab(icon: Icon(Icons.meeting_room), text: 'Odalar'),
              Tab(icon: Icon(Icons.people), text: 'Üyeler'),
              Tab(icon: Icon(Icons.support_agent), text: 'BS BiB Çağrıları'),
              Tab(icon: Icon(Icons.radio), text: 'Radyo Tiyatrosu'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboard(context),
            _buildRoomList(),
            _buildMemberList(),
            _buildBSBibCallsList(),
            _buildRadioTheaterAdmin(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Genel İstatistikler',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: AppFonts.size(20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                tooltip: 'İstatistikleri Yenile',
                onPressed: _refreshDashboardCounts,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<AggregateQuerySnapshot>(
            future: _onlineUsersCountFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final onlineCount = snapshot.hasData ? (snapshot.data!.count ?? 0) : 0;
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OnlineUsersScreen(firestore: _firestore)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Çevrimiçi Kullanıcı: $onlineCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: AppFonts.size(24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<AggregateQuerySnapshot>(
            future: _roomsCountFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final count = snapshot.hasData ? (snapshot.data!.count ?? 0) : 0;
              return InkWell(
                onTap: () {
                  DefaultTabController.of(context).animateTo(1);
                },
                child: Card(
                  color: Colors.blueGrey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Toplam Odalar',
                          style: TextStyle(color: Colors.white, fontSize: AppFonts.size(24)),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(color: Colors.yellow, fontSize: AppFonts.size(32), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<AggregateQuerySnapshot>(
            future: _usersCountFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final count = snapshot.hasData ? (snapshot.data!.count ?? 0) : 0;
              return InkWell(
                onTap: () {
                  DefaultTabController.of(context).animateTo(2);
                },
                child: Card(
                  color: Colors.blueGrey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Toplam Üyeler',
                          style: TextStyle(color: Colors.white, fontSize: AppFonts.size(24)),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(color: Colors.yellow, fontSize: AppFonts.size(32), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportedPostsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
            ),
            child: Text('Şikayet Edilen Gönderiler', style: TextStyle(fontSize: AppFonts.size(20))),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReleaseNotesScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
            ),
            child: Text('Son Sürüm Notları', style: TextStyle(fontSize: AppFonts.size(20))),
          ),
        ],
      ),
    );
  }
}
