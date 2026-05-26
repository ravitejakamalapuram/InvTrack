const { exec } = require('child_process');
const https = require('https');
const util = require('util');
const fs = require('fs');
const execPromise = util.promisify(exec);

// Bypass SSL errors due to local proxy/security software
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

async function getAccessToken() {
  // 1. Try to load from FIREBASE_CREDENTIALS environment variable directly if it is a JSON string
  if (process.env.FIREBASE_CREDENTIALS) {
    try {
      console.error('Generating OAuth2 token from FIREBASE_CREDENTIALS env var...');
      const credentials = JSON.parse(process.env.FIREBASE_CREDENTIALS);
      const { GoogleAuth } = require('google-auth-library');
      const auth = new GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/cloud-platform']
      });
      const client = await auth.getClient();
      const tokenResponse = await client.getAccessToken();
      if (tokenResponse.token) {
        console.error('✅ Access token generated successfully from env credentials');
        return tokenResponse.token;
      }
    } catch (err) {
      console.error('Warning: Failed to authenticate using FIREBASE_CREDENTIALS env var:', err.message);
    }
  }

  // 2. Try to load from GOOGLE_APPLICATION_CREDENTIALS file path
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    try {
      console.error('Generating OAuth2 token from service account keyfile at ' + serviceAccountPath);
      const { GoogleAuth } = require('google-auth-library');
      const auth = new GoogleAuth({
        keyFile: serviceAccountPath,
        scopes: ['https://www.googleapis.com/auth/cloud-platform']
      });
      const client = await auth.getClient();
      const tokenResponse = await client.getAccessToken();
      if (tokenResponse.token) {
        console.error('✅ Access token generated successfully from keyfile');
        return tokenResponse.token;
      }
    } catch (err) {
      console.error('Warning: Failed to authenticate using GOOGLE_APPLICATION_CREDENTIALS keyfile:', err.message);
    }
  }

  // 3. Fallback to Firebase CLI authenticated user or FIREBASE_TOKEN
  try {
    console.error('Attempting token generation via Firebase CLI...');
    const { stdout } = await execPromise('npx -y firebase-tools@latest login:list --json');
    const loginData = JSON.parse(stdout);
    const resultList = loginData.result || [];
    const user = resultList.find(u => u.tokens && u.tokens.access_token) || resultList[0];
    if (user && user.tokens && user.tokens.access_token) {
      console.error('✅ Access token generated successfully from Firebase CLI');
      return user.tokens.access_token;
    }
  } catch (err) {
    console.error('Warning: Firebase CLI token retrieval failed:', err.message);
  }

  // 4. Try FIREBASE_TOKEN directly if available
  if (process.env.FIREBASE_TOKEN) {
    console.error('Using FIREBASE_TOKEN directly...');
    return process.env.FIREBASE_TOKEN;
  }

  throw new Error('All authentication methods failed. Please configure FIREBASE_CREDENTIALS, GOOGLE_APPLICATION_CREDENTIALS, or run firebase login.');
}

function httpRequest(url, method, body, token) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve(data); // Return raw data if not JSON
          }
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function postCrashlyticsNote(appId, issueId, noteText) {
  try {
    const cleanAppId = (appId || '').trim();
    const projectNumber = cleanAppId.split(':')[1];
    const token = await getAccessToken();
    const url = `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${projectNumber}/apps/${cleanAppId}/issues/${issueId}/notes`;
    console.error(`Posting note to Crashlytics issue ${issueId}...`);
    await httpRequest(url, 'POST', { body: noteText }, token);
    console.error(`✅ Successfully posted note to Crashlytics`);
  } catch (err) {
    console.error(`Failed to post note to Crashlytics issue ${issueId}:`, err.message);
  }
}

module.exports = {
  getAccessToken,
  httpRequest,
  postCrashlyticsNote
};
