// Shared unread-count helper
// Notifications: column is `is_read` (NOT `read`)
// Messages: there's no `unread_count` column on conversation_participants;
// we have to count messages where is_read=false in conversations the user is part of.
const supabase = require('./supabase-client');

async function getUnreadBadge(userId) {
  // 1. Unread bell-notifications
  let notifCount = 0;
  try {
    const { count } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('is_read', false);
    notifCount = count || 0;
  } catch (e) {
    console.error('[Badge] notif count error:', e.message);
  }

  // 2. Unread chat messages: get user's conversations, then count messages
  //    where is_read=false and sender != user
  let msgCount = 0;
  try {
    const { data: parts } = await supabase
      .from('conversation_participants')
      .select('conversation_id')
      .eq('user_id', userId);
    const convIds = (parts || []).map(p => p.conversation_id);
    if (convIds.length > 0) {
      const { count } = await supabase
        .from('messages')
        .select('*', { count: 'exact', head: true })
        .in('conversation_id', convIds)
        .neq('user_id', userId)
        .eq('is_read', false);
      msgCount = count || 0;
    }
  } catch (e) {
    console.error('[Badge] msg count error:', e.message);
  }

  const total = notifCount + msgCount;
  console.log('[Badge] user=' + userId.substring(0, 8) + ' notifs=' + notifCount + ' msgs=' + msgCount + ' total=' + total);
  return total;
}

module.exports = { getUnreadBadge };
