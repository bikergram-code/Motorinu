const http = require('http');
const https = require('https');
const crypto = require('crypto');

// Firebase Service Account — load from JSON file or env
const fs = require('fs');
let SA;
try {
  const saPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '/app/firebase-sa.json';
  SA = JSON.parse(fs.readFileSync(saPath, 'utf8'));
  console.log('[Push] Loaded Firebase SA from', saPath);
} catch {
  SA = {
    project_id: "bikergram-2675d",
    client_email: "firebase-adminsdk-fbsvc@bikergram-2675d.iam.gserviceaccount.com",
    private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n') || ''
  };
  console.log('[Push] Using env-based Firebase SA');
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;
// Secret wird aus Umgebung geladen — NICHT im Repo committen!
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || '';
if (!WEBHOOK_SECRET) {
  console.warn('[Push] WARNING: WEBHOOK_SECRET env var not set — webhook auth disabled');
}

// ── JWT + OAuth2 ──────────────────────────────────────────────

function createJWT() {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    iss: SA.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).toString('base64url');
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(`${header}.${payload}`);
  const signature = sign.sign(SA.private_key, 'base64url');
  return `${header}.${payload}.${signature}`;
}

let cachedToken = null;
let tokenExpiry = 0;

async function getAccessToken() {
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;
  const jwt = createJWT();
  const body = `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`;
  return new Promise((resolve, reject) => {
    const req = https.request('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          cachedToken = json.access_token;
          tokenExpiry = Date.now() + (json.expires_in - 60) * 1000;
          resolve(cachedToken);
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── Supabase REST helper ──────────────────────────────────────

function supabaseGet(path) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
      }
    }, (r) => {
      let d = '';
      r.on('data', c => d += c);
      r.on('end', () => {
        try { resolve(JSON.parse(d)); }
        catch { resolve([]); }
      });
    }).on('error', reject);
  });
}

// ── FCM Send ──────────────────────────────────────────────────

async function sendPush(fcmToken, title, body, data) {
  const token = await getAccessToken();
  const message = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: { sound: 'default', channel_id: 'motorinu_default' }
      }
    }
  };
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(message);
    const req = https.request(`https://fcm.googleapis.com/v1/projects/${SA.project_id}/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json; charset=utf-8',
      },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log(`[FCM] OK ${fcmToken.substring(0, 20)}...`);
        } else {
          console.error(`[FCM] ${res.statusCode}: ${data}`);
          // Remove invalid tokens
          try {
            const e = JSON.parse(data);
            const code = e?.error?.details?.[0]?.errorCode || e?.error?.code || '';
            if (code === 'UNREGISTERED' || code === 'NOT_FOUND' || code === 'INVALID_ARGUMENT') {
              supabaseDelete(`user_devices?fcm_token=eq.${encodeURIComponent(fcmToken)}`);
              console.log('[FCM] Removed invalid token');
            }
          } catch {}
        }
        resolve({ status: res.statusCode, data });
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function supabaseDelete(path) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  return new Promise((resolve) => {
    const req = https.request(url, {
      method: 'DELETE',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
      }
    }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve());
    });
    req.on('error', () => resolve());
    req.end();
  });
}

async function pushUser(uid, title, body, data) {
  const devs = await supabaseGet(`user_devices?user_id=eq.${uid}&select=fcm_token`);
  if (!devs || devs.length === 0) {
    console.log(`[Push] No devices for ${uid.substring(0, 8)}`);
    return;
  }
  console.log(`[Push] ${devs.length} device(s) for ${uid.substring(0, 8)}`);
  for (const d of devs) {
    if (d.fcm_token) await sendPush(d.fcm_token, title, body, data);
  }
}

// ── Format vehicle_offer body ─────────────────────────────────

function formatVehicleOffer(rawBody) {
  try {
    const offer = JSON.parse(rawBody);
    const vName = offer.vehicle_name || 'Fahrzeug';
    const price = offer.price != null ? `${offer.price} \u20ac` : '';
    switch (offer.type) {
      case 'direct_buy': return `\ud83d\uded2 Direktkauf: ${price} f\u00fcr ${vName}`;
      case 'offer':      return `\ud83d\udcb0 Angebot: ${price} f\u00fcr ${vName}`;
      case 'counter':    return `\u21a9\ufe0f Gegenangebot: ${price} f\u00fcr ${vName}`;
      case 'accept':     return `\u2705 Angebot angenommen f\u00fcr ${vName}`;
      case 'decline':    return `\u274c Angebot abgelehnt f\u00fcr ${vName}`;
      case 'like':       return `\u2764\ufe0f ${vName} gef\u00e4llt mir`;
      default:           return `Angebot f\u00fcr ${vName}`;
    }
  } catch {
    return 'Fahrzeug-Angebot';
  }
}

// ── Format message preview ────────────────────────────────────

function formatMessagePreview(record) {
  const body = (record.body || '').toString();
  const mt = record.message_type || 'text';

  if (mt === 'vehicle_offer' || (body.startsWith('{') && body.includes('"type"'))) {
    return formatVehicleOffer(body);
  }
  if (mt === 'image' || record.image_url) return '\ud83d\uddbc\ufe0f Bild';
  if (mt === 'audio' || record.audio_url) return '\ud83c\udfa4 Sprachnachricht';
  if (mt === 'location' || record.location_lat) return '\ud83d\udccd Standort';

  // Regular text — truncate
  return body.length > 100 ? body.substring(0, 100) + '...' : body;
}

// ── HTTP Server ───────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  // Health check
  if (req.url === '/health') {
    res.writeHead(200);
    res.end('OK');
    return;
  }

  if (req.method !== 'POST') {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  let rawBody = '';
  req.on('data', c => rawBody += c);
  req.on('end', async () => {
    try {
      // Verify webhook secret
      const secret = req.headers['x-webhook-secret'];
      if (secret && secret !== WEBHOOK_SECRET) {
        console.log('[Webhook] Invalid secret');
        res.writeHead(403);
        res.end('Forbidden');
        return;
      }

      console.log('[Webhook] raw:', rawBody.substring(0, 500));
      const event = JSON.parse(rawBody);
      const table = event.table;
      const record = event.record || {};
      console.log('[Webhook] table:', table, 'type:', event.type, 'record keys:', Object.keys(record));

      // Only handle INSERTs
      if (event.type !== 'INSERT') {
        res.writeHead(200);
        res.end(JSON.stringify({ ok: true, skip: true }));
        return;
      }

      console.log(`[Webhook] ${table} INSERT`);

      // ── NOTIFICATIONS table ──
      if (req.url === '/webhook/notification' || table === 'notifications') {
        const uid = record.user_id;
        const title = record.title || 'Motorinu';
        const body = record.body || '';
        const type = record.type || 'system';
        const dataJson = record.data || {};

        // Build FCM data payload (all values must be strings)
        const fcmData = { type };
        if (typeof dataJson === 'object') {
          for (const [k, v] of Object.entries(dataJson)) {
            if (v != null) fcmData[k] = String(v);
          }
        }

        await pushUser(uid, title, body, fcmData);
      }

      // ── MESSAGES table ──
      else if (req.url === '/webhook/message' || table === 'messages') {
        const conversationId = record.conversation_id;
        const senderId = record.user_id;
        console.log('[Msg] convId:', conversationId, 'senderId:', senderId);

        // Format message preview
        const preview = formatMessagePreview(record);
        console.log('[Msg] preview:', preview);

        // Get sender name
        const profiles = await supabaseGet(`profiles?id=eq.${senderId}&select=display_name,username`);
        const senderName = profiles?.[0]?.display_name || profiles?.[0]?.username || 'Jemand';
        console.log('[Msg] senderName:', senderName);

        // Get all participants except sender
        const parts = await supabaseGet(`conversation_participants?conversation_id=eq.${conversationId}&user_id=neq.${senderId}&select=user_id`);
        console.log('[Msg] participants:', JSON.stringify(parts));

        if (parts && parts.length > 0) {
          for (const p of parts) {
            console.log('[Msg] Pushing to:', p.user_id);
            await pushUser(p.user_id, senderName, preview, {
              type: 'message',
              conversation_id: String(conversationId),
              sender_id: senderId,
            });
          }
        } else {
          console.log('[Msg] No participants found!');
        }
      }

      res.writeHead(200);
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      console.error('[Webhook] Error:', e);
      res.writeHead(500);
      res.end(JSON.stringify({ error: String(e) }));
    }
  });
});

server.listen(3001, () => console.log('[Push] Server running on port 3001'));
