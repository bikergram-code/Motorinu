const { pushToUser } = require('./fcm-auth');
const supabase = require('./supabase-client');

async function getUnreadCount(userId) {
  const { count: notifCount } = await supabase
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('read', false);

  const { count: msgCount } = await supabase
    .from('conversation_participants')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gt('unread_count', 0);

  return (notifCount || 0) + (msgCount || 0);
}

async function handleNotification(record) {
  const userId = record.user_id;
  const title = record.title || 'Bikergram';
  const body = record.body || '';
  const type = record.type || 'system';
  const extra = record.data || {};

  const data = { type };
  for (const [k, v] of Object.entries(extra)) {
    if (v != null) data[k] = String(v);
  }

  const badge = await getUnreadCount(userId);
  data.badge = String(badge);
  await pushToUser(userId, title, body, data, supabase, badge);
}

module.exports = handleNotification;
