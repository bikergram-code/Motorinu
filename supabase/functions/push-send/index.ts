import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const binary = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', binary, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

async function createJwt(email: string, privateKey: string): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const claims = b64url(JSON.stringify({ iss: email, sub: email, aud: 'https://oauth2.googleapis.com/token', scope: 'https://www.googleapis.com/auth/firebase.messaging', iat: now, exp: now + 3600 }));
  const input = new TextEncoder().encode(header + '.' + claims);
  const key = await importPrivateKey(privateKey);
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, input));
  return header + '.' + claims + '.' + b64url(sig);
}

let cachedToken = '';
let tokenExp = 0;

async function getAccessToken(): Promise<string> {
  if (cachedToken && Date.now() < tokenExp - 60000) return cachedToken;
  const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not set');
  const sa = JSON.parse(saJson);
  const jwt = await createJwt(sa.client_email, sa.private_key);
  const res = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt });
  if (!res.ok) throw new Error('Token exchange failed: ' + res.status);
  const data = await res.json();
  cachedToken = data.access_token;
  tokenExp = Date.now() + data.expires_in * 1000;
  return cachedToken;
}

const FCM = 'https://fcm.googleapis.com/v1/projects/bikergram-2675d/messages:send';

async function sendPush(fcmToken: string, title: string, body: string, data: Record<string, string>, sb: ReturnType<typeof createClient>): Promise<void> {
  const at = await getAccessToken();
  const r = await fetch(FCM, { method: 'POST', headers: { Authorization: 'Bearer ' + at, 'Content-Type': 'application/json' }, body: JSON.stringify({ message: { token: fcmToken, notification: { title, body }, data, android: { priority: 'high', notification: { channel_id: 'motorinu_default', sound: 'default' } } } }) });
  if (r.ok) { console.log('[FCM] OK ' + fcmToken.substring(0, 20)); return; }
  const e = await r.json().catch(() => ({}));
  const c = e?.error?.details?.[0]?.errorCode || e?.error?.code || '';
  if (c === 'UNREGISTERED' || c === 'NOT_FOUND' || c === 'INVALID_ARGUMENT') {
    await sb.from('user_devices').delete().eq('fcm_token', fcmToken);
    console.log('[FCM] Removed invalid token');
  } else { console.error('[FCM] Err ' + r.status + ' ' + JSON.stringify(e)); }
}

async function pushUser(uid: string, title: string, body: string, data: Record<string, string>, sb: ReturnType<typeof createClient>): Promise<void> {
  const { data: devs } = await sb.from('user_devices').select('fcm_token').eq('user_id', uid);
  if (!devs || devs.length === 0) { console.log('[Push] No devices for ' + uid.substring(0, 8)); return; }
  console.log('[Push] ' + devs.length + ' device(s)');
  for (const d of devs) await sendPush(d.fcm_token, title, body, data, sb);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
  try {
    const raw = await req.text();
    console.log('[Push] len=' + raw.length + ' raw=' + raw.substring(0, 300));
    // Debug: return raw body info
    if (raw.length < 5) {
      return new Response(JSON.stringify({ error: 'empty body', len: raw.length, raw }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }
    const body = JSON.parse(raw) as Record<string, unknown>;
    const table = body.table as string;
    const rec = body.record as Record<string, unknown>;
    if (body.type !== 'INSERT') return new Response(JSON.stringify({ ok: true, skip: true }), { headers: { 'Content-Type': 'application/json' } });
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    if (table === 'notifications') {
      const uid = rec.user_id as string;
      const t = (rec.title as string) || 'Motorinu';
      const b = (rec.body as string) || '';
      const tp = (rec.type as string) || 'system';
      const dj = (rec.data as Record<string, unknown>) || {};
      const fd: Record<string, string> = { type: tp };
      for (const [k, v] of Object.entries(dj)) { if (v != null) fd[k] = String(v); }
      await pushUser(uid, t, b, fd, sb);
    } else if (table === 'messages') {
      const cid = rec.conversation_id as number;
      const sid = rec.user_id as string;
      const rb = (rec.body as string) || '';
      const mt = (rec.message_type as string) || 'text';
      const { data: prof } = await sb.from('profiles').select('display_name, username').eq('id', sid).maybeSingle();
      const name = prof?.display_name || prof?.username || 'Jemand';
      let prev = rb.substring(0, 100);
      if (mt === 'vehicle_offer') {
        try {
          const offer = JSON.parse(rb);
          const vName = offer.vehicle_name || 'Fahrzeug';
          const price = offer.price != null ? `${offer.price} €` : '';
          if (offer.type === 'direct_buy') prev = `🛒 Direktkauf: ${price} für ${vName}`;
          else if (offer.type === 'offer') prev = `💰 Angebot: ${price} für ${vName}`;
          else if (offer.type === 'counter') prev = `↩️ Gegenangebot: ${price} für ${vName}`;
          else if (offer.type === 'accept') prev = `✅ Angebot angenommen für ${vName}`;
          else if (offer.type === 'decline') prev = `❌ Angebot abgelehnt für ${vName}`;
          else prev = `Angebot für ${vName}`;
        } catch { prev = 'Fahrzeug-Angebot'; }
      }
      else if (mt === 'image' || rec.image_url) prev = 'Bild';
      else if (mt === 'audio' || rec.audio_url) prev = 'Sprachnachricht';
      else if (mt === 'location' || rec.location_lat) prev = 'Standort';
      const { data: parts } = await sb.from('conversation_participants').select('user_id').eq('conversation_id', cid).neq('user_id', sid);
      if (parts && parts.length > 0) {
        for (const p of parts) await pushUser(p.user_id, name, prev, { type: 'message', conversation_id: String(cid), sender_id: sid }, sb);
      }
    }
    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    console.error('[Push]', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
