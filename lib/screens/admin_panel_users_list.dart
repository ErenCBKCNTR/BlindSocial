import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel_user_details.dart';

class AdminPanelUsersList extends StatelessWidget {
  final FirebaseFirestore? firestore;
  const AdminPanelUsersList({super.key, this.firestore});

  @override
  Widget build(BuildContext context) {
    final fs = firestore ?? FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Üyeler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

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
                  title: Text('ID: U$userId - $username', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  subtitle: Text('Kayıt Tarihi: $createdAt', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
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
      ),
    );
  }
}
