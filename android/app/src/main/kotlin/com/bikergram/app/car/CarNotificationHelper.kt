package com.bikergram.app.car

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.graphics.drawable.IconCompat
import com.bikergram.app.MainActivity
import java.net.HttpURLConnection
import java.net.URL

/**
 * Creates MessagingStyle notifications that Android Auto
 * automatically picks up for read-aloud + voice reply.
 *
 * How it works:
 * 1. Flutter receives a message via Supabase Realtime
 * 2. Flutter calls MotoBridge → "showMessageNotification"
 * 3. This helper creates a NotificationCompat.MessagingStyle notification
 * 4. Android Auto detects the notification and:
 *    - Reads it aloud via TTS
 *    - Shows a "Reply" button
 *    - Voice reply comes back via CarMessageReplyReceiver
 */
object CarNotificationHelper {

    private const val TAG = "CarNotifHelper"
    private const val CHANNEL_ID = "motorino_messages"
    private const val CHANNEL_NAME = "Nachrichten"
    private const val GROUP_KEY = "com.bikergram.app.MESSAGES"

    // Key for RemoteInput voice reply
    const val REPLY_KEY = "car_voice_reply"
    const val EXTRA_CONVERSATION_ID = "conversation_id"
    const val EXTRA_SENDER_ID = "sender_id"
    const val EXTRA_SENDER_NAME = "sender_name"

    // Cache of conversation notification IDs (conversationId → notifId)
    private var nextNotifId = 9000
    private val conversationNotifIds = mutableMapOf<Int, Int>()

    // Message history per conversation (for stacking messages)
    private val messageHistory = mutableMapOf<Int, MutableList<Pair<Person, String>>>()

    /**
     * Initialize the notification channel. Call once on app startup.
     */
    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Chat-Nachrichten von Motorino"
            enableVibration(true)
            setShowBadge(true)
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
        Log.d(TAG, "Notification channel created: $CHANNEL_ID")
    }

    /**
     * Show a MessagingStyle notification for an incoming message.
     *
     * @param context       Application context
     * @param conversationId  Supabase conversation ID
     * @param senderId      Sender's user ID
     * @param senderName    Display name of sender
     * @param senderAvatarUrl  Optional avatar URL (will be fetched in background)
     * @param messageBody   The message text (or description like "Foto" / "Sprachnachricht")
     * @param timestamp     Message timestamp in millis
     */
    fun showMessageNotification(
        context: Context,
        conversationId: Int,
        senderId: String,
        senderName: String,
        senderAvatarUrl: String?,
        messageBody: String,
        timestamp: Long
    ) {
        Log.d(TAG, "showMessageNotification: conv=$conversationId, sender=$senderName, body=$messageBody")

        // Get or create notification ID for this conversation
        val notifId = conversationNotifIds.getOrPut(conversationId) { nextNotifId++ }

        // Build the Person object (sender)
        val personBuilder = Person.Builder()
            .setName(senderName)
            .setKey(senderId)

        // Try to load avatar (synchronously for simplicity — called from background already)
        val avatar = loadAvatarBitmap(senderAvatarUrl)
        if (avatar != null) {
            personBuilder.setIcon(IconCompat.createWithBitmap(avatar))
        }

        val sender = personBuilder.build()

        // Add to message history (Android Auto shows conversation thread)
        val history = messageHistory.getOrPut(conversationId) { mutableListOf() }
        history.add(Pair(sender, messageBody))
        // Keep max 10 messages in history
        if (history.size > 10) {
            history.removeAt(0)
        }

        // Build MessagingStyle
        val messagingStyle = NotificationCompat.MessagingStyle(
            Person.Builder().setName("Ich").build() // "Me" / current user
        )
            .setConversationTitle(senderName)
            .setGroupConversation(false)

        // Add all messages in history
        for ((person, text) in history) {
            messagingStyle.addMessage(text, timestamp, person)
        }

        // ── Reply action (voice reply for Android Auto) ──
        val remoteInput = RemoteInput.Builder(REPLY_KEY)
            .setLabel("Antworten")
            .build()

        val replyIntent = Intent(context, CarMessageReplyReceiver::class.java).apply {
            putExtra(EXTRA_CONVERSATION_ID, conversationId)
            putExtra(EXTRA_SENDER_ID, senderId)
            putExtra(EXTRA_SENDER_NAME, senderName)
        }

        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            conversationId, // unique per conversation
            replyIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            "Antworten",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .build()

        // ── Mark as Read action ──
        val markReadIntent = Intent(context, CarMessageReplyReceiver::class.java).apply {
            action = "com.bikergram.app.MARK_READ"
            putExtra(EXTRA_CONVERSATION_ID, conversationId)
        }

        val markReadPendingIntent = PendingIntent.getBroadcast(
            context,
            conversationId + 50000,
            markReadIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val markReadAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Gelesen",
            markReadPendingIntent
        )
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .setShowsUserInterface(false)
            .build()

        // ── Tap action (open chat in app) ──
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/messages/$conversationId")
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            conversationId + 100000,
            tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // ── Build notification ──
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email) // TODO: use your app icon
            .setStyle(messagingStyle)
            .addAction(replyAction)
            .addAction(markReadAction)
            .setContentIntent(tapPendingIntent)
            .setAutoCancel(true)
            .setGroup(GROUP_KEY)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setShortcutId(senderId) // Links to sharing shortcut
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notifId, notification)
            Log.d(TAG, "Notification posted: id=$notifId, conv=$conversationId")
        } catch (e: SecurityException) {
            Log.e(TAG, "Notification permission not granted", e)
        }
    }

    /**
     * Cancel notification for a conversation (e.g. when user opens the chat).
     */
    fun cancelForConversation(context: Context, conversationId: Int) {
        val notifId = conversationNotifIds[conversationId] ?: return
        NotificationManagerCompat.from(context).cancel(notifId)
        messageHistory.remove(conversationId)
        Log.d(TAG, "Cancelled notification for conv=$conversationId")
    }

    /**
     * Load avatar bitmap from URL (blocking — call from background thread).
     */
    private fun loadAvatarBitmap(url: String?): Bitmap? {
        if (url.isNullOrBlank()) return null
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 3000
            connection.readTimeout = 3000
            connection.doInput = true
            connection.connect()
            val input = connection.inputStream
            val bitmap = BitmapFactory.decodeStream(input)
            input.close()
            connection.disconnect()
            // Scale down to 64x64 for notification icon
            bitmap?.let { Bitmap.createScaledBitmap(it, 64, 64, true) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load avatar: $url", e)
            null
        }
    }
}
