# Blind Social - Mimari Yapı (Architecture Structure)

## Proje Klasör Ağacı ve Mimari Dağılım

Projemiz Flutter (Dart) ile geliştirilmiş olup standart ve ölçeklenebilir bir yapı takip etmektedir. Kök dizindeki klasörlerin temel görevleri şu şekildedir:

- `lib/` : Uygulamanın tüm kaynak kodlarını barındırır.
- `android/` & `ios/` : Platformlara özgü native yapılandırma ve izin dosyaları.
- `assets/` : Uygulama içindeki görseller ve statik medya dosyaları (örn. `assets/images/icon.png`, `assets/images/radio_cover.png`).
- `functions/` : Güvenli backend işlemleri için yazılmış Firebase Cloud Functions kodları (Node.js/TypeScript tabanlı, token üretimi ve şifre onayı gibi işlemler için).
- `test/` : Birim (unit) ve widget testlerini barındıran klasör.

### `lib/` Klasörü Detaylı İncelemesi

Aşağıdaki liste `lib` altındaki klasörleri ve en önemli dosyaların işlevlerini açıklar:

#### 1. `lib/main.dart`
Uygulamanın giriş noktasıdır. `main` fonksiyonunu barındırır, uygulamanın çalıştırılmasından önce gerekli paket başlatma (Firebase, MediaKit, AudioService vb.) ve izin (PermissionManager) işlemlerini gerçekleştirir. Kullanıcı durumuna göre ilk açılacak ekranı belirler (Splash, Update, Onboarding veya Login).

#### 2. `lib/services/`
Uygulamanın dış dünyayla olan bağlantılarını, iş mantığını ve arkaplan görevlerini yöneten servis sınıfları burada yer alır.
- `audio_cache_manager.dart`: Ses dosyalarının bellekte önbelleğe alınmasını (cache) yönetir.
- `audio_favorites_manager.dart`: Kullanıcının favori ses içeriklerini kaydetmesi ve yönetmesi için SharedPreferences destekli servis.
- `audio_handler.dart`: Arka planda ses oynatımı için cihaz ile iletişim kuran (bildirim menüsündeki durdur/başlat butonları) AudioService implementasyonu.
- `audio_progress_manager.dart`: Ses oynatılırken geçerli sürenin ve pozisyonun takip edilmesini sağlar.
- `broadcast_record_manager.dart`: Radyo/medya yayınlarının arka planda kaydedilmesiyle ilgilenir.
- `permission_manager.dart`: Uygulamanın mikrofon, depolama ve bildirim gibi izinlerini platform bağımsız (Android/iOS) yönetir. Cihaz başlangıcında zorunlu izinlerin istenmesini sağlar.
- `radio_proxy_server.dart`: Radyo dinlerken veriyi alıp bir yandan çalarken diğer yandan kaydetmeyi veya önbelleklemeyi sağlayan yerel bir proxy sunucu mantığı. (Bu servis `audio_handler.dart` ile entegre çalışır).

#### 3. `lib/widgets/`
Uygulama genelinde tekrar kullanılabilir UI bileşenleri (widget'lar).
- `custom_bottom_sheet.dart`: Tüm bottom sheet'lerin global ve tek tip görünmesi için kullanılan (isScrollControlled destekli) sarıcı widget.
- `global_background_wrapper.dart` & `global_call_overlay.dart`: Canlı aramalar ve global arka plan dinlemeleri/bildirimleri için uygulamanın her yerinde üstte duran katmanlar.
- `accessible_icon_button.dart`: Uygulama genelinde TalkBack/VoiceOver uyumlu (etiketsiz ve çift okuma hatalarından arındırılmış) dairesel ikon butonlar yaratmak için evrensel araç.

#### 4. `lib/theme/`
Görsel kimlik, tipografi ve tema yönetimi bileşenleri.
- `app_theme.dart`: Uygulamanın ışık ve karanlık tema (veya genel engellilere yönelik yüksek kontrast) ayarları.
- `app_fonts.dart`: Global font büyüklüklerini ayarlayan ve "Declutter" mantığını uygulayan font yönetim dosyası.
- `theme_notifier.dart`: Tema değişikliklerinin uygulama genelinde (ValueListenable vb.) algılanmasını sağlayan state mekanizması.

#### 5. `lib/screens/`
Kullanıcıya gösterilen ekranların (sayfaların) bulunduğu klasör.
- **Kimlik Doğrulama:** `login_screen.dart`, `register_screen.dart`, `onboarding_screen.dart` (Giriş, kayıt ve karşılama)
- **Ana Ekran ve Profil:** `square_screen.dart` (Meydan, ana akış), `profile_screen.dart`, `meydan_profile_screen.dart` (Kullanıcı profilleri)
- **Sohbet ve İletişim:** `chat_rooms_screen.dart` (Oda listesi), `chat_screen.dart` (Aktif sohbet/yazışma ekranı), `bs_bib_call_screen.dart` (Görüşme/Arama ekranı)
- **Medya ve Radyo:** `live_radio_player_screen.dart`, `live_media_screen.dart`, `radio_theater_screen.dart`, `radio_theater_player_screen.dart` (Radyo ve medya oynatma arayüzleri)
- **İçerik:** `news_screen.dart`, `news_detail_screen.dart`, `post_comments_screen.dart` (Haberler ve gönderi detayları)
- **Yönetim ve Diğer:** `admin_panel_screen.dart`, `admin_panel_room_details.dart`, `admin_panel_user_details.dart`, `reported_posts_screen.dart` (Yönetici paneli ve şikayetler), `online_users_screen.dart` (Aktif kullanıcılar), `update_screen.dart` (Zorunlu güncelleme ekranı), `release_notes_screen.dart` (Sürüm notları).

### Dosya ve Servis İlişkileri (Mimari Akış)

- **Ses ve Medya Akışı:**
  Kullanıcı `live_radio_player_screen.dart` ekranında bir radyo oynattığında, ekran `audio_handler.dart` servisi üzerinden tetikleme yapar. Arkaplan ve cihaz entegrasyonları için `audio_handler.dart` çağrılır, veri akışı ise senkronizasyon bozulmalarını önlemek için tek bir stream üzerinden `radio_proxy_server.dart` üzerinden geçirilir. Gerekirse `broadcast_record_manager.dart` devreye girip dosyayı yazar.

- **Veritabanı ve Arayüz İlişkisi:**
  Tüm ekranlar (`screens/`) verileri Firebase'den okur/yazar. Özellikle `chat_screen.dart` ve `chat_rooms_screen.dart` ekranları `cloud_firestore` paketini kullanarak gerçek zamanlı verileri dinler (Snapshot listener). Şifreli odalara giriş yaparken `functions/` altındaki Firebase Cloud Functions ile doğrulama yapılır, istemciden sadece sonuç beklenir.

- **LiveKit / WebRTC Görüşmeleri:**
  Arama ve oda içi sesli iletişim özellikleri `livekit_client` kullanır.
  - **Sesli Odalar (Voice Rooms):** `chat_screen.dart` vb. ekranlardan yönetilir ve bağlantı için yeni kendi Hetzner sunucumuz (`wss://live.cabukcan.com`) kullanılır. Gerekli LiveKit token'ları güvenli bir şekilde (`process.env` kullanılarak) Firebase Functions üzerinden çekilir.
  - **P2P Aramalar (BS Bip):** `bs_bib_call_screen.dart` üzerinden yönetilir ve tamamen bağımsız/eski bir bağlantı mantığı kullanmaya devam eder.

- **Global Sahiplik (App-Level Wrappers):**
  `main.dart` içinde uygulamanın temel `MaterialApp` widget'ı, `global_call_overlay.dart` ve `global_background_wrapper.dart` ile sarmalanır. Bu sayede kullanıcı ekranlar arasında (örneğin sohbetten meydana) geçiş yapsa bile arkaplandaki aramalar (Call) ve medya yayınları kesintiye uğramaz.

### Genel Mimari Prensipler
1. **İş Mantığı ve UI Ayrımı:** UI dosyaları (screens) sadece görseli ve kullanıcı etkileşimini tanımlar, kompleks iş mantığı ve cihaz özellikleri `services/` klasöründeki sınıflarda çözülür.
2. **Erişilebilirlik Odaklı Geliştirme (Accessibility - a11y):** Uygulama görme engelliler için tasarlandığından tüm `screens/` içi UI elemanlarında ve animasyonlarda yoğun olarak Semantics widget'ı ve ekran okuyucu uyumluluğu gözetilmiştir.
