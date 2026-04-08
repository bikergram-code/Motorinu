const express = require('express');
const handleNotification = require('./lib/handle-notification');
const handleMessage = require('./lib/handle-message');
const supabase = require('./lib/supabase-client');

const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ ok: true, uptime: process.uptime(), mode: 'polling', lastPoll: lastPollTime });
});

// Webhook endpoints disabled — polling handles everything reliably
// Keeping endpoints alive to return 200 (avoids webhook retry noise)
app.post('/webhook/notification', (req, res) => {
  res.json({ ok: true, skip: 'polling-only' });
});
app.post('/webhook/message', (req, res) => {
  res.json({ ok: true, skip: 'polling-only' });
});

// ============================================================
// Dedup — track recently handled IDs to avoid double-push
// ============================================================
const handledNotifs = new Set();
const handledMsgs = new Set();
const DEDUP_MAX = 200;

function markHandled(set, id) {
  set.add(id);
  if (set.size > DEDUP_MAX) {
    const first = set.values().next().value;
    set.delete(first);
  }
}

// ============================================================
// Polling — check for new notifications and messages every 3s
// ============================================================
let lastNotifId = 0;
let lastMsgId = 0;
let lastPollTime = null;
let polling = false;

async function initLastIds() {
  const { data: n } = await supabase.from('notifications').select('id').order('id', { ascending: false }).limit(1);
  if (n && n.length > 0) lastNotifId = n[0].id;

  const { data: m } = await supabase.from('messages').select('id').order('id', { ascending: false }).limit(1);
  if (m && m.length > 0) lastMsgId = m[0].id;

  console.log('[Poll] Init: lastNotifId=' + lastNotifId + ' lastMsgId=' + lastMsgId);
}

async function pollNotifications() {
  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .gt('id', lastNotifId)
    .order('id', { ascending: true })
    .limit(20);

  if (error) { console.error('[Poll] notifications error:', error.message); return; }
  if (!data || data.length === 0) return;

  for (const row of data) {
    console.log('[Poll] notification id=' + row.id + ' for user ' + (row.user_id || '').substring(0, 8));
    try { await handleNotification(row); } catch (e) { console.error('[Poll] handle error:', e.message); }
    lastNotifId = row.id;
  }
}

async function pollMessages() {
  const { data, error } = await supabase
    .from('messages')
    .select('*')
    .gt('id', lastMsgId)
    .order('id', { ascending: true })
    .limit(20);

  if (error) { console.error('[Poll] messages error:', error.message); return; }
  if (!data || data.length === 0) return;

  for (const row of data) {
    console.log('[Poll] message id=' + row.id + ' in conv ' + row.conversation_id);
    try { await handleMessage(row); } catch (e) { console.error('[Poll] handle error:', e.message); }
    lastMsgId = row.id;
  }
}

async function poll() {
  if (polling) return;
  polling = true;
  try {
    lastPollTime = new Date().toISOString();
    await pollNotifications();
    await pollMessages();
  } finally {
    polling = false;
  }
}

const PORT = process.env.PORT || 3001;
app.listen(PORT, async () => {
  console.log('[Push Service] Running on port ' + PORT);
  await initLastIds();
  setInterval(poll, 3000);
  console.log('[Poll] Polling every 3s');
});
