import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPK(pem: string): Promise<CryptoKey> {
  const pemBody = pem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const bin = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', bin, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

async function makeJwt(email: string, pk: string): Promise<string> {
  const h = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const p = b64url(JSON.stringify({ iss: email, sub: email, aud: 'https://oauth2.googleapis.com/token', scope: 'https://www.googleapis.com/auth/firebase.messaging', iat: now, exp: now + 3600 }));
  const inp = new TextEncoder().encode(h + '.' + p);
  const key = await importPK(pk);
  const s = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, inp));
  return h + '.' + p + '.' + b64url(s);
}

let tok = '';
let tokExp = 0;

async function getToken(): Promise<string> {
  if (tok && Date.now() < tokExp - 60000) return tok;
  const j = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!j) throw new Error('No SA');
  const sa = JSON.parse(j);
  const jwt = await makeJwt(sa.client_email, sa.private_key);
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt });
  if (!r.ok) throw new Error('Token fail ' + r.status);
  const d = await r.json();
  tok = d.access_token;
  tokExp = Date.now() + d.expires_in * 1000;
  return tok;
}

type SB = ReturnType<typeof createClient>;
const FCM = 'https://fcm.googleapis.com/v1/projects/bikergram-2675d/messages:send';

async function fcmSend(ft: string, title: string, bdy: string, data: Record<string, string>, sb: SB): Promise<void> {
  const at = await getToken();
  const r = await fetch(FCM, { method: 'POST', headers: { Authorization: 'Bearer ' + at, 'Content-Type': 'application/json' }, body: JSON.stringify({ message: { token: ft, notification: { title: title, body: bdy }, data: data, android: { priority: 'high', notification: { channel_id: 'motorinu_default', sound: 'default' } } } }) });
  if (r.ok) { console.log('[FCM] OK'); return; }
  const e = await r.json().catch(function() { return {}; });
  const c = (e && e.error && e.error.details && e.error.details[0] && e.error.details[0].errorCode) || (e && e.error && e.error.code) || '';
  if (c === 'UNREGISTERED' || c === 'NOT_FOUND' || c === 'INVALID_ARGUMENT') {
    await sb.from('user_devices').delete().eq('fcm_token', ft);
  } else {
    console.error('[FCM] ' + r.status + ' ' + JSON.stringify(e));
  }
}

async function pushTo(uid: string, title: string, bdy: string, data: Record<string, string>, sb: SB): Promise<void> {
  const res = await sb.from('user_devices').select('fcm_token').eq('user_id', uid);
  const devs = res.data;
  if (!devs || devs.length === 0) { console.log('[Push] No devs'); return; }
  for (let i = 0; i < devs.length; i++) { await fcmSend(devs[i].fcm_token, title, bdy, data, sb); }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
  try {
    const raw = await req.text();
    console.log('[Push] len=' + raw.length);
    const body = JSON.parse(raw);
    if (body.type !== 'INSERT') return new Response('{"ok":true}', { headers: { 'Content-Type': 'application/json' } });
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const tbl = body.table;
    const rec = body.record;
    if (tbl === 'notifications') {
      const fd: Record<string, string> = { type: rec.type || 'system' };
      if (rec.data) { const ks = Object.keys(rec.data); for (let i = 0; i < ks.length; i++) { if (rec.data[ks[i]] != null) fd[ks[i]] = String(rec.data[ks[i]]); } }
      await pushTo(rec.user_id, rec.title || 'Bikergram', rec.body || '', fd, sb);
    } else if (tbl === 'messages') {
      const sid = rec.user_id;
      const cid = rec.conversation_id;
      const profRes = await sb.from('profiles').select('display_name, username').eq('id', sid).maybeSingle();
      const prof = profRes.data;
      const nm = (prof && prof.display_name) || (prof && prof.username) || 'Jemand';
      let prev = (rec.body || '').substring(0, 100);
      if (rec.message_type === 'vehicle_offer') {
        try {
          const offer = JSON.parse(rec.body || '{}');
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
      else if (rec.message_type === 'image' || rec.image_url) prev = 'Bild';
      else if (rec.message_type === 'audio' || rec.audio_url) prev = 'Sprachnachricht';
      else if (rec.message_type === 'location' || rec.location_lat) prev = 'Standort';
      const partsRes = await sb.from('conversation_participants').select('user_id').eq('conversation_id', cid).neq('user_id', sid);
      const parts = partsRes.data;
      if (parts) { for (let i = 0; i < parts.length; i++) { await pushTo(parts[i].user_id, nm, prev, { type: 'message', conversation_id: String(cid), sender_id: sid }, sb); } }
    }
    return new Response('{"ok":true}', { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    console.error('[Push]', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
