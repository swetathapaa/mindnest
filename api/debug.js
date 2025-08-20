module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const debug = {
      timestamp: new Date().toISOString(),
      hasFirebaseServiceAccount: !!process.env.FIREBASE_SERVICE_ACCOUNT,
      firebaseServiceAccountLength: process.env.FIREBASE_SERVICE_ACCOUNT ? process.env.FIREBASE_SERVICE_ACCOUNT.length : 0,
      firebaseEnvVars: Object.keys(process.env).filter(key => key.includes('FIREBASE')),
      nodeVersion: process.version,
      platform: process.platform
    };

    // Try to parse the service account if it exists
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        debug.serviceAccountFields = Object.keys(parsed);
        debug.hasRequiredFields = !!(parsed.project_id && parsed.private_key && parsed.client_email);
        debug.projectId = parsed.project_id;
        debug.clientEmail = parsed.client_email;
        debug.privateKeyStart = parsed.private_key ? parsed.private_key.substring(0, 50) + '...' : null;
      } catch (parseError) {
        debug.parseError = parseError.message;
        debug.firstChars = process.env.FIREBASE_SERVICE_ACCOUNT.substring(0, 100);
      }
    }

    return res.status(200).json({ debug });
  } catch (error) {
    console.error('Debug endpoint error:', error);
    return res.status(500).json({ error: error.message });
  }
};
