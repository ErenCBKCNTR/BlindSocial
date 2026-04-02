# Firebase Cloud Functions (LiveKit Token)

Sesli sohbet (Voice Chat) özelliğiniz için gereken `generateLiveKitToken` fonksiyonu başarıyla oluşturuldu.
Güvenlik nedeniyle (API Secret gibi bilgilerin cihaz tarafında bulunmaması gerektiğinden), bu kod parçasının Firebase Cloud Functions'a yüklenmesi gerekmektedir.

## Yükleme Adımları:

1. Terminalinizde `functions` klasörüne girin:
   ```bash
   cd functions
   ```

2. İlgili bağımlılıkları yükleyin (eğer yüklenmediyse):
   ```bash
   npm install
   ```

3. `functions/src/index.ts` dosyasına gidip kendi **LIVEKIT_API_KEY** ve **LIVEKIT_API_SECRET** bilgilerinizi dosyadaki ilgili alana yapıştırın. (Bu dosyayı düzenleyici bir programla açarak ilgili yerleri güncelleyebilirsiniz).

4. Düzenlediğiniz kodu derleyin:
   ```bash
   npm run build
   ```

5. Firebase projelerinize yükleme yapın:
   ```bash
   firebase deploy --only functions
   ```

*Not: Eğer daha önce bilgisayarınızda `firebase-tools` kurulu değilse, önce `npm install -g firebase-tools` komutuyla yükleyip, `firebase login` ile giriş yapmanız gerekebilir.*

Bu işlemler tamamlandığında fonksiyon Firebase üzerine yüklenecek ve `NOT_FOUND` hatası çözülecektir.
