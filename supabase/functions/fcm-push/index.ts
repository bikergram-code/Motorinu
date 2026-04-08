import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPK(pem: string) {
  const pemBody = pem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const bin = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', bin, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

async function makeJwt(email: string, pk: string) {
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

async function getToken() {
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

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok');
  try {
    const raw = await req.text();
    console.log('[Push] len=' + raw.length);
    const body = JSON.parse(raw);
    if (body.type !== 'INSERT') return new Response('{"ok":true}', { headers: { 'Content-Type': 'application/json' } });
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const tbl = body.table;
    const rec = body.record;
    const uid = rec.user_id;
    const devRes = await sb.from('user_devices').select('fcm_token').eq('user_id', uid);
    const devs = devRes.data;
    if (!devs || devs.length === 0) {
      console.log('[Push] No devices for ' + uid);
      return new Response('{"ok":true,"devs":0}', { headers: { 'Content-Type': 'application/json' } });
    }
    const at = await getToken();
    const fcmUrl = 'https://fcm.googleapis.com/v1/projects/bikergram-2675d/messages:send';
    let title = rec.title || 'Bikergram';
    let bdy = rec.body || '';
    const data: Record<string, string> = { type: rec.type || 'message' };
    if (tbl === 'messages') {
      const profRes = await sb.from('profiles').select('display_name, username').eq('id', uid).maybeSingle();
      const prof = profRes.data;
      title = (prof && prof.display_name) || (prof && prof.username) || 'Jemand';
      const mt = rec.message_type || 'text';
      if (mt === 'vehicle_offer') {
        try {
          const offer = JSON.parse(bdy || '{}');
          const vName = offer.vehicle_name || 'Fahrzeug';
          const price = offer.price != null ? `${offer.price} €` : '';
          if (offer.type === 'direct_buy') bdy = `🛒 Direktkauf: ${price} für ${vName}`;
          else if (offer.type === 'offer') bdy = `💰 Angebot: ${price} für ${vName}`;
          else if (offer.type === 'counter') bdy = `↩️ Gegenangebot: ${price} für ${vName}`;
          else if (offer.type === 'accept') bdy = `✅ Angebot angenommen für ${vName}`;
          else if (offer.type === 'decline') bdy = `❌ Angebot abgelehnt für ${vName}`;
          else bdy = `Angebot für ${vName}`;
        } catch { bdy = 'Fahrzeug-Angebot'; }
      } else if (mt === 'image' || rec.image_url) { bdy = 'Bild'; }
      else if (mt === 'audio' || rec.audio_url) { bdy = 'Sprachnachricht'; }
      else if (mt === 'location' || rec.location_lat) { bdy = 'Standort'; }
      else { bdy = bdy.substring(0, 100) || 'Neue Nachricht'; }
      data.conversation_id = String(rec.conversation_id || '');
      data.sender_id = uid;
    }
    if (rec.data) {
      const ks = Object.keys(rec.data);
      for (let i = 0; i < ks.length; i++) {
        if (rec.data[ks[i]] != null) data[ks[i]] = String(rec.data[ks[i]]);
      }
    }
    let sent = 0;
    for (let i = 0; i < devs.length; i++) {
      const fcmRes = await fetch(fcmUrl, { method: 'POST', headers: { Authorization: 'Bearer ' + at, 'Content-Type': 'application/json' }, body: JSON.stringify({ message: { token: devs[i].fcm_token, notification: { title: title, body: bdy }, data: data, android: { priority: 'high', notification: { channel_id: 'motorinu_default', sound: 'default' } } } }) });
      if (fcmRes.ok) { sent++; console.log('[FCM] OK'); }
      else { const e = await fcmRes.text(); console.error('[FCM] ' + fcmRes.status + ' ' + e); }
    }
    return new Response(JSON.stringify({ ok: true, sent: sent }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    console.error('[Push]', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
