// Direct FCM HTTP v1 client — no Edge Function proxy.
// Generates Google OAuth access token from service account, then POSTs to FCM.
const crypto = require('crypto');
const fs = require('fs');

let serviceAccount = null;
let cachedAccessToken = '';
let tokenExp = 0;

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

async function getAccessToken() {
  if (cachedAccessToken && Date.now() < tokenExp - 60000) return cachedAccessToken;
  const jwt = createJwt();
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error('Token exchange failed: ' + res.status + ' ' + t);
  }
  const d = await res.json();
  cachedAccessToken = d.access_token;
  tokenExp = Date.now() + d.expires_in * 1000;
  return cachedAccessToken;
}

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'bikergram-2675d';
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;

async function sendFcmPush(fcmToken, title, body, data, supabase, badge) {
  try {
    const at = await getAccessToken();
    const androidNotification = { channel_id: 'motorinu_default', sound: 'default' };
    if (badge) androidNotification.notification_count = badge;
    const message = {
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: 'high', notification: androidNotification },
    };
    const res = await fetch(FCM_URL, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + at,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    });
    if (res.ok) {
      console.log('[FCM] OK ' + fcmToken.substring(0, 20) + (badge ? ' badge=' + badge : ''));
      return true;
    }
    const errText = await res.text();
    console.error('[FCM] Error ' + res.status + ' ' + errText);
    if (errText.includes('UNREGISTERED') || errText.includes('NOT_FOUND') || errText.includes('INVALID_ARGUMENT')) {
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
