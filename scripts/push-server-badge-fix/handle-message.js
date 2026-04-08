const { pushToUser } = require('./fcm-auth');
const supabase = require('./supabase-client');
const { getUnreadBadge } = require('./get-unread');

async function handleMessage(record) {
  // Support both new format (user_id/conversation_id/body) and old format (sender_id/receiver_id/content)
  const senderId = record.user_id || record.sender_id;
  const conversationId = record.conversation_id;
  const body = record.body || record.content || '';
  const messageType = record.message_type || 'text';

  if (!senderId) {
    console.log('[Push] Message has no sender_id, skipping');
    return;
  }

  // Get sender profile
  const { data: prof } = await supabase
    .from('profiles')
    .select('display_name, username')
    .eq('id', senderId)
    .maybeSingle();
  const senderName = prof?.display_name || prof?.username || 'Jemand';

  // Determine preview text
  let preview = body.substring(0, 100);
  if (messageType === 'image' || record.image_url) preview = 'Bild';
  else if (messageType === 'audio' || record.audio_url) preview = 'Sprachnachricht';
  else if (messageType === 'location' || record.location_lat) preview = 'Standort';
  else if (messageType === 'vehicle_offer') {
    try {
      const o = JSON.parse(body);
      const vName = o.vehicle_name || 'Fahrzeug';
      const price = o.price != null ? `${o.price} €` : (o.amount != null ? `${o.amount} €` : '');
      switch (o.type) {
        case 'direct_buy': preview = `🛒 Direktkauf: ${price} für ${vName}`; break;
        case 'offer': preview = `💰 Angebot: ${price} für ${vName}`; break;
        case 'counter': preview = `↩️ Gegenangebot: ${price} für ${vName}`; break;
        case 'accepted': preview = `✅ Angebot angenommen für ${vName}`; break;
        case 'declined': preview = `❌ Angebot abgelehnt für ${vName}`; break;
        case 'like': preview = `❤️ ${vName} gefällt mir`; break;
        default: preview = `Angebot für ${vName}`;
      }
    } catch { preview = 'Fahrzeug-Angebot'; }
  }
  if (!preview) preview = 'Neue Nachricht';

  // If we have conversation_id, get all participants except sender
  if (conversationId) {
    const { data: parts } = await supabase
      .from('conversation_participants')
      .select('user_id')
      .eq('conversation_id', conversationId)
      .neq('user_id', senderId);

    if (!parts || parts.length === 0) {
      console.log('[Push] No participants for conversation ' + conversationId);
      return;
    }

    const data = {
      type: 'message',
      conversation_id: String(conversationId),
      sender_id: senderId,
    };

    for (const p of parts) {
      const badge = await getUnreadBadge(p.user_id);
      const pData = { ...data, badge: String(badge) };
      await pushToUser(p.user_id, senderName, preview, pData, supabase, badge);
    }
  } else if (record.receiver_id) {
    // Old format: direct receiver_id
    const badge = await getUnreadBadge(record.receiver_id);
    const data = {
      type: 'message',
      sender_id: senderId,
      badge: String(badge),
    };
    await pushToUser(record.receiver_id, senderName, preview, data, supabase, badge);
  }
}

module.exports = handleMessage;
