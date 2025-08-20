const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
let firebaseInitialized = false;
try {
  let serviceAccount;
  
  // Try multiple environment variable formats
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } catch (parseError) {
      console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT:", parseError.message);
      throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
    }
  } else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
    // Alternative: separate environment variables
    serviceAccount = {
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      client_email: process.env.FIREBASE_CLIENT_EMAIL
    };
  } else {
    throw new Error("Firebase credentials not found. Set FIREBASE_SERVICE_ACCOUNT or individual Firebase environment variables");
  }

  // Validate required service account fields
  if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
    throw new Error("Invalid service account: missing required fields (project_id, private_key, client_email)");
  }

  console.log("Initializing Firebase Admin with project:", serviceAccount.project_id);

  // Initialize Firebase Admin if not already initialized
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id
    });
    console.log("Firebase Admin initialized successfully");
  }
  
  firebaseInitialized = true;
} catch (error) {
  console.error("Firebase Admin initialization error:", error.message);
  console.error("Available env vars:", Object.keys(process.env).filter(key => key.includes('FIREBASE')));
  firebaseInitialized = false;
}

module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Check if Firebase was properly initialized
  if (!firebaseInitialized) {
    console.error("Firebase Admin not initialized");
    return res.status(500).json({ 
      error: "Server configuration error: Firebase not initialized",
      details: "Please check server logs for Firebase initialization errors"
    });
  }

  try {
    const { title, message, tokens } = req.body;
    
    console.log('Received notification request:', { title, message, tokenCount: tokens?.length });

    if (!title || !message || !tokens || !Array.isArray(tokens)) {
      return res.status(400).json({ error: "Missing or invalid fields. Required: title, message, tokens (array of FCM tokens)" });
    }

    if (!tokens.length) {
      return res.status(400).json({ error: "No FCM tokens provided" });
    }

    // Validate that tokens are strings and not empty
    const validTokens = tokens.filter(token => typeof token === 'string' && token.trim().length > 0);
    
    if (!validTokens.length) {
      return res.status(400).json({ error: "No valid FCM tokens found" });
    }

    const messages = validTokens.map((token) => ({
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
