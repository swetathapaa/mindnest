require("dotenv").config();
const admin = require("firebase-admin");
const { getMessaging } = require("firebase-admin/messaging");

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

// Helper function to batch tokens in chunks of 500
const chunkArray = (array, size = 500) => {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

// Debug function for GET requests
const debug = (req, res) => {
  try {
    const messaging = getMessaging();
    res.status(200).json({
      firebaseAdminVersion: admin.SDK_VERSION,
      messagingMethods: Object.keys(messaging),
      firebaseInitialized,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method === "GET") return debug(req, res);
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

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

    const messaging = getMessaging();
    const chunks = chunkArray(validTokens, 500);

    const results = [];
    for (const chunk of chunks) {
      const response = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body: message },
      });
      results.push(response);
    }

    return res.status(200).json({ success: true, results });
  } catch (error) {
    console.error("Error sending notification:", error);
    return res.status(500).json({ error: error.message });
  }
};
