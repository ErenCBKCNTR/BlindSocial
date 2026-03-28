import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelReportedPostDetails extends StatelessWidget {
  final Map<String, dynamic> report;
  final String reportDocId;

  const AdminPanelReportedPostDetails({super.key, required this.report, required this.reportDocId});

  Future<void> _deletePost(BuildContext context, String postId) async {
    try {
      await FirebaseFirestore.instance.collection('meydan_posts').doc(postId).delete();
      await FirebaseFirestore.instance.collection('reported_posts').doc(reportDocId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi ve şikayet silindi.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String postId = report['postId'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Şikayet Detayı')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('meydan_posts').doc(postId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Gönderi bulunamadı veya silinmiş.'));
          }

          var post = snapshot.data!.data() as Map<String, dynamic>;
          String content = post['content'] ?? 'Bilinmiyor';
          String authorUsername = post['authorUsername'] ?? 'Bilinmiyor';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gönderen: $authorUsername', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(content, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _deletePost(context, postId),
                  child: const Text('Bu Gönderiyi Sil', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
