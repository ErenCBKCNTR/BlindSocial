import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel_rooms_list.dart';
import 'admin_panel_users_list.dart';
import 'admin_panel_reported_post_details.dart';
import 'admin_panel_room_details.dart';
import 'admin_panel_user_details.dart';
import 'admin_panel_reported_post_details.dart';

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
                  'ID: U$userId - $username',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kayıt Tarihi: $createdAt',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                ),
                trailing: ElevatedButton(
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
            );
          },
        );
      },
    );
  }

  Widget _buildReportedPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('reported_posts').orderBy('reportedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Bir hata oluştu.'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Şikayet bulunamadı.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var report = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String docId = snapshot.data!.docs[index].id;
            String postId = report['postId'] ?? 'Bilinmiyor';

            Timestamp? reportedAtTimestamp = report['reportedAt'] as Timestamp?;
            String reportedAt = reportedAtTimestamp != null
                ? "${reportedAtTimestamp.toDate().hour}:${reportedAtTimestamp.toDate().minute} - ${reportedAtTimestamp.toDate().day}/${reportedAtTimestamp.toDate().month}/${reportedAtTimestamp.toDate().year}"
                : "Bilinmiyor";

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text('Gönderi ID: $postId', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                subtitle: Text('Şikayet Zamanı: $reportedAt', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminPanelReportedPostDetails(report: report, reportDocId: docId),
                      ),
                    );
                  },
                  child: Text('İncele', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Yönetici Paneli', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.secondary,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Genel Bakış'),
              Tab(icon: Icon(Icons.report), text: 'Şikayetler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Dashboard
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanelRoomsList(firestore: _firestore))),
                      child: Card(
                        color: Colors.grey[900],
                        child: Center(
                          child: StreamBuilder<AggregateQuerySnapshot>(
                            stream: _firestore.collection('chat_rooms').count().get().asStream(),
                            builder: (context, snapshot) {
                              String count = snapshot.hasData ? snapshot.data!.count.toString() : '...';
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.meeting_room, size: 50, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(height: 10),
                                  Text('Odalar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24)),
                                  Text('Toplam: $count', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18)),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanelUsersList(firestore: _firestore))),
                      child: Card(
                        color: Colors.grey[900],
                        child: Center(
                          child: StreamBuilder<AggregateQuerySnapshot>(
                            stream: _firestore.collection('users').count().get().asStream(),
                            builder: (context, snapshot) {
                              String count = snapshot.hasData ? snapshot.data!.count.toString() : '...';
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people, size: 50, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(height: 10),
                                  Text('Üyeler', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24)),
                                  Text('Toplam: $count', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18)),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Şikayetler
            _buildReportedPostsList(),
          ],
        ),
      ),
    );
  }
}
