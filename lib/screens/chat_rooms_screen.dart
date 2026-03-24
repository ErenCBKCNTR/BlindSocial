import 'package:flutter/material.dart';

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
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Bilgilendirme mesajı',
              child: const Icon(
                Icons.forum,
                size: 100,
                color: Colors.yellow,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Henüz bir sohbet odası yok mesajı',
              child: Text(
                'Henüz bir sohbet odası bulunmuyor.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
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
                },
                child: const Text('Yeni Oda Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
