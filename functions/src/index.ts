import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { AccessToken } from "livekit-server-sdk";

admin.initializeApp();

export const generateLiveKitToken = functions.https.onCall(async (data, context) => {
  // Enforce secure authentication check using Firebase Auth context
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı girişi yapılmamış."
    );
  }

  // Güvenlik uyarısı: Üretim (Production) ortamında bu değerleri her zaman
  // Firebase Secret Manager veya çevresel değişkenler üzerinden yönetin.
  // Not: Yeni Hetzner sunucusu anahtarları yapılandırılmalıdır.
  const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY;
  const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET;

  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
    console.error("LiveKit API Key or Secret is missing in environment variables.");
    throw new functions.https.HttpsError(
      "internal",
      "Sunucu yapılandırma hatası."
    );
  }

  const room = data.room;
  const identity = data.identity;

  if (!room || !identity) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Oda veya kullanıcı bilgisi eksik."
    );
  }

  try {
    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity: identity,
      ttl: "10m",
    });

    at.addGrant({ roomJoin: true, room: room });

    const token = await at.toJwt();
    return { token: token };
  } catch (error) {
    console.error("Token generation error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Token oluşturulurken bir hata oluştu."
    );
  }
});
