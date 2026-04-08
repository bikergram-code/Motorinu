const { pushToUser } = require('./fcm-auth');
const supabase = require('./supabase-client');
const { getUnreadBadge } = require('./get-unread');

async function handleNotification(record) {
  const userId = record.user_id;
  const title = record.title || 'Motorinu';
  const body = record.body || '';
  const type = record.type || 'system';
  const extra = record.data || {};

  const data = { type };
  for (const [k, v] of Object.entries(extra)) {
    if (v != null) data[k] = String(v);
  }

  const badge = await getUnreadBadge(userId);
  data.badge = String(badge);
  await pushToUser(userId, title, body, data, supabase, badge);
}

module.exports = handleNotification;
