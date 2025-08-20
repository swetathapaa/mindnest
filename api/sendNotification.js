import admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  const { title, message, userIds } = req.body;

  try {
    const tokens = [];
    for (let uid of userIds) {
      const snap = await admin.firestore().collection("Users").doc(uid).get();
      if (snap.exists && snap.data().fcmToken) tokens.push(snap.data().fcmToken);
    }

    if (tokens.length === 0) return res.status(400).json({ error: "No tokens found" });

    const payload = { notification: { title, body: message } };
    await admin.messaging().sendToDevice(tokens, payload);

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
}
