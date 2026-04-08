const crypto = require('crypto');
const fs = require('fs');

let serviceAccount = null;

function loadServiceAccount() {
  if (serviceAccount) return serviceAccount;
  const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (path) {
    serviceAccount = JSON.parse(fs.readFileSync(path, 'utf8'));
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  } else {
    throw new Error('No Firebase service account configured');
  }
  return serviceAccount;
}

function b64url(data) {
  const buf = typeof data === 'string' ? Buffer.from(data) : data;
  return buf.toString('base64url');
}

function createJwt() {
  const sa = loadServiceAccount();
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    iat: now,
    exp: now + 3600,
  }));
  const input = header + '.' + claims;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(input);
  const signature = b64url(sign.sign(sa.private_key));
  return input + '.' + signature;
}

// Call the tiny Edge Function which proxies to Google FCM
const EDGE_URL = (process.env.SUPABASE_URL || '') + '/functions/v1/fcm-send';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRybXdia3BmYWZpZ3JhdmVuZXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDYyODMsImV4cCI6MjA4NjY4MjI4M30.aUyG0Pn0dTv68jVXBXZpGgwumaiVNOQo96t-i-sL-w8';

async function sendFcmPush(fcmToken, title, body, data, supabase, badge) {
  const jwt = createJwt();
  try {
    const payload = { jwt, fcmToken, title, body, data };
    if (badge) payload.badge = badge;
    const res = await fetch(EDGE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + ANON_KEY,
      },
      body: JSON.stringify(payload),
    });
    const result = await res.json();
    if (result.ok) {
      console.log('[FCM] OK ' + fcmToken.substring(0, 20) + (badge ? ' badge=' + badge : ''));
      return true;
    }
    console.error('[FCM] Error:', result.status, result.body);
    // Clean up invalid tokens
    if (result.body && (result.body.includes('UNREGISTERED') || result.body.includes('NOT_FOUND') || result.body.includes('INVALID_ARGUMENT'))) {
      await supabase.from('user_devices').delete().eq('fcm_token', fcmToken);
      console.log('[FCM] Removed invalid token');
    }
    return false;
  } catch (err) {
    console.error('[FCM] fetch error:', err.message);
    return false;
  }
}

async function pushToUser(userId, title, body, data, supabase, badge) {
  const { data: devs } = await supabase.from('user_devices').select('fcm_token').eq('user_id', userId);
  if (!devs || devs.length === 0) {
    console.log('[Push] No devices for ' + userId.substring(0, 8));
    return;
  }
  console.log('[Push] ' + devs.length + ' device(s) for ' + userId.substring(0, 8));
  for (const d of devs) {
    await sendFcmPush(d.fcm_token, title, body, data, supabase, badge);
  }
}

module.exports = { sendFcmPush, pushToUser };
