import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineUsersScreen extends StatelessWidget {
  final FirebaseFirestore? firestore;

  const OnlineUsersScreen({super.key, this.firestore});

  @override
  Widget build(BuildContext context) {
    final db = firestore ?? FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Çevrimiçi Üyeler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('users').where('isOnline', isEqualTo: 1).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.yellow));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Şu an çevrimiçi kimse yok.',
                style: TextStyle(color: Colors.grey, fontSize: AppFonts.size(18)),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final username = data['username'] ?? 'İsimsiz';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    radius: 6,
                  ),
                  title: Text(
                    '@$username',
                    style: TextStyle(color: Colors.white, fontSize: AppFonts.size(18)),
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
