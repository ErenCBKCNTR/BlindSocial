import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportedPostsScreen extends StatelessWidget {
  const ReportedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şikayet Edilen Gönderiler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reported_posts').orderBy('reportedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final reports = snapshot.data!.docs;
          if (reports.isEmpty) return const Center(child: Text('Şikayet bulunmuyor.'));

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index].data() as Map<String, dynamic>;
              final postId = report['postId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('meydan_posts').doc(postId).get(),
                builder: (context, postSnapshot) {
                  if (!postSnapshot.hasData) return const SizedBox.shrink();

                  final numericId = report['reportedByNumericId']?.toString() ?? 'Bilinmiyor';
                  final username = report['reportedByUsername'] ?? 'Bilinmiyor';

                  String reporterInfo = 'Şikayet Eden: U$numericId ($username)';

                  if (postSnapshot.data!.exists) {
                    final post = postSnapshot.data!.data() as Map<String, dynamic>;
                    final authorUsername = post['authorUsername'] ?? 'Bilinmiyor';
                    // We only have authorId which is Firebase UID, but maybe we can just show the username
                    reporterInfo += '\nŞikayet Edilen: @$authorUsername';
                  }

                  if (!postSnapshot.data!.exists) {
                    // Post already deleted
                    return ListTile(
                      title: const Text('Silinmiş Gönderi', style: TextStyle(color: Colors.red)),
                      subtitle: Text(reporterInfo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        tooltip: 'Şikayeti Yoksay/Sil',
                        onPressed: () {
                          FirebaseFirestore.instance.collection('reported_posts').doc(reports[index].id).delete();
                        },
                      ),
                    );
                  }

                  final post = postSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(post['content'] ?? ''),
                      subtitle: Text(reporterInfo),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Gönderiyi Sil',
                            onPressed: () {
                              FirebaseFirestore.instance.collection('meydan_posts').doc(postId).delete();
                              FirebaseFirestore.instance.collection('reported_posts').doc(reports[index].id).delete();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            tooltip: 'Şikayeti Yoksay/Sil',
                            onPressed: () {
                              FirebaseFirestore.instance.collection('reported_posts').doc(reports[index].id).delete();
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // View post isolated
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
