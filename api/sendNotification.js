require("dotenv").config();
const admin = require("firebase-admin");

// Initialize Firebase Admin
let firebaseInitialized = false;

try {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT env var is missing");
  }

  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

  if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
    throw new Error("Invalid service account JSON: missing required fields");
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log("✅ Firebase Admin initialized successfully");
  }

  firebaseInitialized = true;
} catch (err) {
  console.error("❌ Firebase Admin initialization error:", err.message);
  firebaseInitialized = false;
}

// Debug endpoint (optional)
const debug = (req, res) => {
  res.status(200).json({
    firebaseAdminVersion: admin.SDK_VERSION,
    messagingMethods: firebaseInitialized ? Object.keys(admin.messaging()) : [],
    firebaseInitialized,
  });
};

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();

  if (req.method === "GET") return debug(req, res); // GET to check version/debug

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  if (!firebaseInitialized) {
    return res.status(500).json({
      error: "Server configuration error: Firebase not initialized",
      details: "Check Vercel logs for Firebase initialization errors",
    });
  }

  try {
    const { title, message, tokens } = req.body;

    if (!title || !message || !tokens || !Array.isArray(tokens)) {
      return res.status(400).json({
        error: "Missing or invalid fields. Required: title, message, tokens (array of FCM tokens)",
      });
    }

    const validTokens = tokens.filter((t) => typeof t === "string" && t.trim());

    if (!validTokens.length) return res.status(400).json({ error: "No valid FCM tokens found" });

    // Send notification
    const response = await admin.messaging().sendMulticast({
      tokens: validTokens,
      notification: { title, body: message },
    });

    return res.status(200).json({ success: true, response });
  } catch (error) {
    console.error("Error sending notification:", error);
    return res.status(500).json({ error: error.message });
  }
};
