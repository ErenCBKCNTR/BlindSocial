import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';

class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> notes = [
      'BS Meydan akışına aşağı kaydırarak yenileme (Pull-to-Refresh) özelliği getirildi.',
      'Aşırı veri tabanı yükünü önlemek için yenileme süresine kısıtlama eklendi.',
      'Ekran okuyucuların buton isimlerini çift okuması ve etiketsiz uyarısı vermesi düzeltildi.',
      'Yönetici panelindeki çevrimiçi kullanıcılar özelliği doğrudan sayıya tıklanarak açılacak şekilde yenilendi.',
      'Sistem hatalarındaki teknik isimler gizlenerek hata mesajları sadeleştirildi.',
      'BS Meydan için Instagram benzeri profil arayüzü eklendi.',
      'Profilden göderi silme ve düzenleme işlemleri aktifleştirildi.',
      'Kullanıcıları takip etme ve takipten çıkma sistemi eklendi.',
      'Profil sayfasına sesli komutla biyografi ekleme desteği getirildi.',
      'BS Meydan gönderi akışında yapay zeka destekli, takip edilen ve popüler içerikleri karma gösteren yeni algoritma devreye alındı.',
      'Gönderi tasarımı, satır aralıkları ve yazı boyutları okunaklılığı artırmak adına yenilendi.',
      'Yönetici panelinden son sürüm notları ve çevrimiçi üyeleri görüntüleme imkanı sağlandı.',
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Son Sürüm Notları')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notes[index],
                      style: TextStyle(color: Colors.white, fontSize: AppFonts.size(16), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
