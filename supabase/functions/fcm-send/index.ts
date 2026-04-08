import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
let tok = '', exp = 0
serve(async (req) => {
  const { jwt, fcmToken, title, body, data, badge } = await req.json()
  if (!tok || Date.now() > exp) {
    const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt })
    const d = await r.json()
    tok = d.access_token
    exp = Date.now() + (d.expires_in - 60) * 1000
  }
  const n: Record<string,unknown> = { channel_id: 'motorinu_default', sound: 'default' }
  if (badge) n.notification_count = badge
  const f = await fetch('https://fcm.googleapis.com/v1/projects/bikergram-2675d/messages:send', { method: 'POST', headers: { Authorization: 'Bearer ' + tok, 'Content-Type': 'application/json' }, body: JSON.stringify({ message: { token: fcmToken, notification: { title, body }, data, android: { priority: 'high', notification: n } } }) })
  const txt = await f.text()
  return new Response(JSON.stringify({ ok: f.ok, status: f.status, body: txt }), { headers: { 'Content-Type': 'application/json' } })
})
