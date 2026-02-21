package com.bikergram.app.car

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.RemoteInput
import com.bikergram.app.MotoBridge

/**
 * Receives voice replies from Android Auto and "Mark as Read" actions.
 *
 * When the user replies via voice on the car display:
 * 1. Android Auto captures the speech → converts to text
 * 2. This receiver gets the text via RemoteInput
 * 3. We forward it to Flutter via MotoBridge MethodChannel
 * 4. Flutter sends the message to Supabase
 */
class CarMessageReplyReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CarMsgReply"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val conversationId = intent.getIntExtra(CarNotificationHelper.EXTRA_CONVERSATION_ID, -1)

        if (intent.action == "com.bikergram.app.MARK_READ") {
            Log.d(TAG, "Mark as read: conv=$conversationId")
            // Forward to Flutter
            MotoBridge.sendMarkRead(conversationId)
            // Cancel the notification
            CarNotificationHelper.cancelForConversation(context, conversationId)
            return
        }

        // ── Voice reply ──
        val remoteInput = RemoteInput.getResultsFromIntent(intent)
        val replyText = remoteInput?.getCharSequence(CarNotificationHelper.REPLY_KEY)?.toString()

        if (replyText.isNullOrBlank()) {
            Log.w(TAG, "Empty reply received for conv=$conversationId")
            return
        }

        val senderId = intent.getStringExtra(CarNotificationHelper.EXTRA_SENDER_ID) ?: ""
        val senderName = intent.getStringExtra(CarNotificationHelper.EXTRA_SENDER_NAME) ?: ""

        Log.d(TAG, "Voice reply: conv=$conversationId, text='$replyText'")

        // Forward reply to Flutter via MotoBridge
        MotoBridge.sendVoiceReply(conversationId, replyText)

        // Update the notification to show the sent reply
        CarNotificationHelper.showMessageNotification(
            context = context,
            conversationId = conversationId,
            senderId = "self",
            senderName = "Ich",
            senderAvatarUrl = null,
            messageBody = replyText,
            timestamp = System.currentTimeMillis()
        )
    }
}
