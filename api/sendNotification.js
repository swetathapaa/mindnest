const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");

let app;
try {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

  if (!admin.apps.length) {
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
} catch (error) {
  console.error("Firebase Admin initialization error:", error);
}

const db = getFirestore();

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { title, message, userIds } = req.body;

    if (!title || !message || !userIds || !Array.isArray(userIds)) {
      return res.status(400).json({ error: "Missing or invalid fields" });
    }

    // Get FCM tokens for userIds
    const tokens = [];
    for (const userId of userIds) {
      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (!tokens.length) {
      return res.status(400).json({ error: "No valid FCM tokens found" });
    }

    const messages = tokens.map((token) => ({
      notification: { title, body: message },
      token,
    }));

    const response = await admin.messaging().sendAll(messages);

    return res.status(200).json({ success: true, response });
  } catch (error) {
    console.error("Error sending notification:", error);
    return res.status(500).json({ error: error.message });
  }
};
