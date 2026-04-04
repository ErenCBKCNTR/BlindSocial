# Blind Social - Proje Hafızası (Project Memory)

## Proje Amacı
Görme engelliler için özel olarak tasarlanmış, erişilebilirliği maksimum düzeyde olan bir sosyal medya platformu (Blind Social). Flutter ve Dart kullanılarak geliştirilmektedir. Amaç, ekran okuyucu (TalkBack/VoiceOver) uyumluluğunu en ön planda tutarak kullanıcıların radyo dinleyebildiği, birbirleriyle sohbet edebildiği, arama yapabildiği ve içerik paylaşabildiği engelsiz bir ortam yaratmaktır.

## Teknolojik Yığın (Tech Stack)
Proje modern bir Flutter mimarisi üzerine kuruludur. Temel teknolojiler şunlardır:
- **Framework & Dil:** Flutter, Dart (SDK ^3.11.0).
- **Durum Yönetimi (State Management):** ValueNotifier, Stream ve yerel UI state yönetimi (`setState`). Tema için `ValueListenableBuilder` kullanılmaktadır.
- **Backend & Veritabanı:** Firebase Core, Cloud Firestore, Firebase Auth, Firebase Storage. Ayrıca gelişmiş arka uç iş mantıkları (token yönetimi, şifre onaylama) için Firebase Cloud Functions.
- **Gerçek Zamanlı İletişim:** `livekit_client` (WebRTC tabanlı sesli/görüntülü oda ve arama özellikleri için).
- **Medya Oynatma:** `just_audio`, `audioplayers`, `media_kit`, `audio_service` (Arka plan ses kontrolleri ve radyo).
- **Yerel Depolama & İzinler:** `shared_preferences`, `permission_handler`.

## API ve Servis Entegrasyonları
Projede kullanılan tüm temel dış servisler ve entegrasyon noktaları:
- **Firebase Auth (`lib/screens/login_screen.dart`, vb.):** Kullanıcı kayıt, giriş ve oturum açma işlemleri.
- **Cloud Firestore (`lib/screens/` içindeki birçok dosya):** Uygulama verilerinin (kullanıcı profilleri, sohbet mesajları, odalar, meydan paylaşımları, radyo listeleri) gerçek zamanlı saklanması.
- **Firebase Storage (`lib/screens/chat_screen.dart`, profil düzenleme vb.):** Sesli mesaj, profil fotoğrafı ve diğer medya içeriklerinin depolanması.
- **Firebase Cloud Functions (`functions/` klasörü):**
  - Güvenli şekilde LiveKit token üretimi (Görüşmelere/Odalara katılım için yetkilendirme).
  - Kilitli sohbet odalarına girerken şifre doğrulamasının sunucu tarafında yapılarak güvenliğin sağlanması.
- **LiveKit Client (`lib/screens/bs_bib_call_screen.dart`, görüşme mantıkları):** Kullanıcıların birbirleriyle veya grup olarak eşzamanlı sesli görüşme yapabilmesini sağlar.
- **Radio Proxy Server (`lib/services/radio_proxy_server.dart`):** Dışarıdan alınan radyo (HTTP stream) yayınlarını cihaza alır, arabelleğe alır, bir yandan `just_audio` ile çalarken bir yandan da `broadcast_record_manager.dart` vasıtasıyla kaydetme yeteneği sunar.

## Tamamlanan İşler
Bugüne kadar projemizde kodlanıp bitirilen temel özellikler şunlardır:
- Kimlik doğrulama akışı (Kayıt, Giriş, Onboarding).
- Profil sistemi (Kullanıcı profili ve diğer kişilerin profillerini görüntüleme).
- Meydan ekranı (Kullanıcıların genel akışta içerik paylaşıp görebildiği ana sayfa).
- Sohbet sistemi (Birebir ve oda bazlı yazılı/sesli sohbet özellikleri, mesaj silme, ttl - time to live yapılandırmaları).
- Canlı arama altyapısı (Livekit destekli sesli iletişim / odalar).
- Medya/Radyo oynatıcı (Radyo dinleme, arka planda çalma, yayını kaydetme).
- Yönetici paneli (Odaları, kullanıcıları, şikayet edilen içerikleri inceleme ve yönetme).
- Kapsamlı Semantics (Ekran Okuyucu) destekleri ve "Declutter" tasarım mantığı (Yazı boyutu standardizasyonu).
- Cihaz bazlı yetkilendirme akışları (Permission Manager ile).
- Sesli Odalar (Voice Rooms) içinde ekran okuyucu (Semantics) iyileştirmelerinin yapılması, çift okumaların temizlenmesi.
- Sesli Odalarda "Sustur" (Mute) butonunun PTT (Bas-Konuş) veya Ses Aktivasyonu moduna uygun olarak LiveKit local audio track state ile senkronize çalışmasının sağlanması.
- Sesli Odalarda 'Eko İptali', 'Gürültü Bastırma', 'Otomatik Ses Kazancı' switch'leri ile 'Ses Kazancı' ve 'VAD Hassasiyeti' sürgülerinin (slider) LiveKit 'AudioCaptureOptions' donanımsal ayarlarına gerçek zamanlı olarak (UI durumunu bozmadan) entegre edilmesi.
- Sesli Odalarda oynatılan veya paylaşılan medya dosyaları için `_audioPlayer.onPositionChanged` kullanılarak gerçek zamanlı ve doğru süre hesaplamasının yapılması, oynatım bittiğinde kilitlenen mikrofonun `_setMicrophoneEnabled(true)` ile otomatik olarak tekrar açılmasının (Track Conflict) çözülmesi.
- Adım 1 (Bas-Konuş/PTT Butonu Düzeltmesi): Kullanıcı Bas-Konuş modundayken "Konuş" butonundaki Tooltip'in kaldırılarak `onTapDown` (basılı tut) eyleminin `GestureDetector` tarafından güvenli şekilde algılanıp mikrofonu sorunsuz yönetmesinin sağlanması (Semantics yapısı korunarak).
- Adım 2 (Alt Bar Yerleşim Sırası): Alt mesajlaşma alanındaki (bottom bar) ses kaydı ve mesaj gönderme butonlarının yerleri değiştirildi (Semantics yapısı korunarak Ses Kaydı Gönder butonu en sağa alındı).
- Adım 1 (Mikrofon Donanım Restart Mantığı): Sesli Odalar ekranında Eko İptali, Gürültü Bastırma veya Ses Kazancı ayarları değiştirildiğinde `AudioCaptureOptions`'ın dinamik uygulanabilmesi için mevcut LiveKit mikrofon track'inin durdurulup yeni seçeneklerle yeniden başlatılması sağlandı. Atıl ve bozuk MP3 stream (loopback) kodları kaldırıldı.

## Üzerinde Çalışılan Görev
**Arayüz hataları giderildi, yeni talimat bekleniyor.**

## ⚠️ TEMEL KURAL (GROUND RULE)
Bundan sonraki **her** yeni özellik eklemesinde, büyük kod değişikliklerinde veya yeni dosya oluşturulmasında bu iki dosya (`STRUCTURE.md` ve `MEMORY.md`) mutlaka güncellenmelidir. **Bu dosyalar güncellenmeden Pull Request (PR) gönderilmeyecektir.** Herhangi bir asistan bu kuralı kati suretle uygulamalıdır.

## ⚠️ DİL KURALI (LANGUAGE RULE)
Bundan sonra benimle olan tüm iletişimlerin, GitHub commit mesajların, Pull Request başlıkların, PR açıklamaların ve kod içindeki tüm açıklama satırların (yorumlar) KESİNLİKLE ve SADECE Türkçe dilinde olacaktır. İngilizce commit atmak veya İngilizce yanıt vermek kesinlikle yasaktır.
