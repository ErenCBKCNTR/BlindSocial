import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { AccessToken } from "livekit-server-sdk";

admin.initializeApp();

// You should replace these with your actual LiveKit API Key and Secret
// Or use Firebase Secret Manager / environment variables
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || "your_livekit_api_key";
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || "your_livekit_api_secret";

export const generateLiveKitToken = functions.https.onCall(async (data, context) => {
  // Checking that the user is authenticated.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Kullanıcı girişi yapılmamış."
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
