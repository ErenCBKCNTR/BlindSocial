import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatRoomsScreen extends StatelessWidget {
  const ChatRoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Sohbet Odaları Başlığı',
          child: const Text('Sohbet Odaları'),
        ),
        actions: [
          Semantics(
            label: 'Çıkış Yap butonu',
            hint: 'Giriş ekranına geri dönmek için dokunun',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout, size: 30),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Semantics(
                label: 'Bir hata oluştu: ${snapshot.error}',
                child: Text(
                  'Bir hata oluştu.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Semantics(
                label: 'Sohbet odaları yükleniyor, lütfen bekleyin',
                child: const CircularProgressIndicator(strokeWidth: 6),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Henüz aktif sunucu veya oda bulunmuyor.',
                    child: Column(
                      children: [
                        const Icon(Icons.forum, size: 100, color: Colors.yellow),
                        const SizedBox(height: 20),
                        Text(
                          'Henüz bir sohbet odası bulunmuyor.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Semantics(
                    label: 'Yeni Oda Oluştur butonu',
                    hint: 'Yeni bir sohbet odası başlatmak için dokunun',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        // Logic to create a room
                        FirebaseFirestore.instance.collection('chat_rooms').add({
                          'name': 'Yeni Oda ${DateTime.now().millisecond}',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      },
                      child: const Text('Yeni Oda Oluştur'),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var room = snapshot.data!.docs[index];
              var roomName = room['name'] ?? 'İsimsiz Oda';
              var roomId = room.id;

              return Semantics(
                label: '$roomName sohbet odası',
                hint: 'Odaya girmek için iki kez dokunun',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.meeting_room,
                      color: Colors.cyan, size: 30),
                  title: Text(
                    roomName,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          roomId: roomId,
                          roomName: roomName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
