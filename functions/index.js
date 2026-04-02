const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.verifyRoomPassword = functions.https.onCall(async (data, context) => {
    // Authentication check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
    }

    const roomId = data.roomId;
    const password = data.password;

    if (!roomId || !password) {
        throw new functions.https.HttpsError('invalid-argument', 'The function must be called with roomId and password.');
    }

    try {
        const db = admin.firestore();

        // Use a transaction to ensure atomic reads/writes
        return await db.runTransaction(async (transaction) => {
            const roomRef = db.collection('chat_rooms').doc(roomId);
            const roomDoc = await transaction.get(roomRef);

            if (!roomDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'The requested room does not exist.');
            }

            // In a fully secure architecture, the password would be in a protected subcollection.
            // e.g., const secretDoc = await transaction.get(roomRef.collection('secrets').doc('password'));
            // const correctPassword = secretDoc.exists ? secretDoc.data().value : null;
            // Since we're dealing with existing data, we'll read it from the roomDoc for now,
            // but the client will no longer have read access to the 'password' field in the main doc
            // once Firestore rules are updated to exclude it (using a granular read rule or splitting the document).
            // For now, we assume the architectural change moves the password to the secrets subcollection.

            const secretDocRef = roomRef.collection('secrets').doc('password');
            const secretDoc = await transaction.get(secretDocRef);

            let correctPassword;
            if (secretDoc.exists) {
                correctPassword = secretDoc.data().value;
            } else {
                // Fallback for rooms created before the architectural change
                correctPassword = roomDoc.data().password;
            }

            if (password !== correctPassword) {
                return { success: false };
            }

            // If password is correct, grant access by adding the user to the participants subcollection
            const uid = context.auth.uid;

            // Get user info for the participant document
            const userRef = db.collection('users').doc(uid);
            const userDoc = await transaction.get(userRef);
            const userData = userDoc.exists ? userDoc.data() : {};
            const displayName = userData.display_preference === 'fullName'
                ? (userData.fullName || 'Anonim')
                : (userData.username || 'Anonim');

            // Increment currentParticipants
            transaction.update(roomRef, {
                currentParticipants: admin.firestore.FieldValue.increment(1)
            });

            // Add to participants subcollection
            const participantRef = roomRef.collection('participants').doc(uid);
            transaction.set(participantRef, {
                uid: uid,
                displayName: displayName,
                joinedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            return { success: true };
        });
    } catch (error) {
        console.error('Error verifying password:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'An error occurred while verifying the password.');
    }
});
