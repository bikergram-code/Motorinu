package com.bikergram.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.bikergram.app.car.CarNotificationHelper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Singleton bridge between Flutter (Dart) and Android Auto (Car App Library).
 *
 * Handles bidirectional communication:
 * - Flutter → Kotlin: message notifications, navigation state, search results
 * - Kotlin → Flutter: voice replies, mark-read, search queries, route mode
 */
object MotoBridge {
    private const val TAG = "MotoBridge"
    private const val CHANNEL_NAME = "com.bikergram.app/android_auto"

    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var appContext: Context? = null

    // ── Listener interface for Car screens ──

    interface CarActionListener {
        fun onNavigationStateUpdate(state: Map<String, Any?>)
        fun onSearchResults(results: List<Map<String, Any?>>)
        fun onNavigationStarted()
        fun onNavigationEnded()
    }

    // ── POI data callback ──
    // Called with the result after fetchPoiData returns from Flutter/Supabase.
    private var poiDataCallback: ((List<Map<String, Any?>>) -> Unit)? = null

    private var listener: CarActionListener? = null

    val isInitialized: Boolean get() = methodChannel != null

    // ── Initialization ──

    fun init(messenger: BinaryMessenger, context: Context? = null) {
        appContext = context?.applicationContext

        // Create notification channel on init
        appContext?.let { CarNotificationHelper.createChannel(it) }

        methodChannel = MethodChannel(messenger, CHANNEL_NAME).apply {
            setMethodCallHandler { call, result ->
                Log.d(TAG, "Received from Flutter: ${call.method}")
                when (call.method) {

                    // ── Messaging: Flutter shows a notification for Android Auto ──
                    "showMessageNotification" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args != null && appContext != null) {
                            // Run on background thread (avatar download is blocking)
                            Thread {
                                CarNotificationHelper.showMessageNotification(
                                    context = appContext!!,
                                    conversationId = (args["conversationId"] as? Number)?.toInt() ?: 0,
                                    senderId = args["senderId"] as? String ?: "",
                                    senderName = args["senderName"] as? String ?: "Unbekannt",
                                    senderAvatarUrl = args["senderAvatarUrl"] as? String,
                                    messageBody = args["messageBody"] as? String ?: "",
                                    timestamp = (args["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis()
                                )
                            }.start()
                        }
                        result.success(null)
                    }

                    // ── Messaging: Cancel notification when chat is opened ──
                    "cancelMessageNotification" -> {
                        val convId = (call.arguments as? Number)?.toInt() ?: 0
                        if (appContext != null) {
                            CarNotificationHelper.cancelForConversation(appContext!!, convId)
                        }
                        result.success(null)
                    }

                    // Flutter pushes live navigation state
                    "updateNavigation" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args != null) {
                            listener?.onNavigationStateUpdate(args)
                        }
                        result.success(null)
                    }

                    // Flutter signals navigation started
                    "navigationStarted" -> {
                        listener?.onNavigationStarted()
                        result.success(null)
                    }

                    // Flutter signals navigation ended
                    "navigationEnded" -> {
                        listener?.onNavigationEnded()
                        result.success(null)
                    }

                    // Flutter sends geocoding search results
                    "updateSearchResults" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? List<Map<String, Any?>>
                        listener?.onSearchResults(args ?: emptyList())
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
        Log.d(TAG, "Bridge initialized on channel: $CHANNEL_NAME")
    }

    fun setListener(l: CarActionListener?) {
        listener = l
        Log.d(TAG, "Listener ${if (l != null) "registered" else "cleared"}")
    }

    // ── Kotlin → Flutter calls ──

    /** Voice reply from Android Auto car display. */
    fun sendVoiceReply(conversationId: Int, text: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onVoiceReply", mapOf(
                "conversationId" to conversationId,
                "text" to text
            ))
        }
    }

    /** Mark conversation as read (from Android Auto). */
    fun sendMarkRead(conversationId: Int) {
        mainHandler.post {
            methodChannel?.invokeMethod("onMarkRead", conversationId)
        }
    }

    /** User typed/said a search query on the car display. */
    fun sendSearchQuery(query: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onSearchQuery", query)
        }
    }

    /** User selected a search result on the car display. */
    fun sendSearchSelected(index: Int, lat: Double, lng: Double, name: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onSearchSelected", mapOf(
                "index" to index,
                "lat" to lat,
                "lng" to lng,
                "name" to name
            ))
        }
    }

    /** User stopped navigation from the car display. */
    fun sendStopNavigation() {
        mainHandler.post {
            methodChannel?.invokeMethod("onStopNavigation", null)
        }
    }

    /** User toggled route mode (biker/auto) from the car display. */
    fun sendRouteModeToggle(mode: String) {
        mainHandler.post {
            methodChannel?.invokeMethod("onRouteMode", mode)
        }
    }

    // ── POI data request ──

    /**
     * Request POI data from Flutter/Supabase for the given category.
     * [category] = "events" | "blitzer" | "spots"
     * [lat]/[lng] = optional current position for proximity filtering
     * [onResult] = called on the main thread with the list of items
     */
    fun fetchPoiData(
        category: String,
        lat: Double? = null,
        lng: Double? = null,
        onResult: (List<Map<String, Any?>>) -> Unit
    ) {
        mainHandler.post {
            val args = mutableMapOf<String, Any?>("category" to category)
            if (lat != null) args["lat"] = lat
            if (lng != null) args["lng"] = lng

            methodChannel?.invokeMethod(
                "fetchPoiData",
                args,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        @Suppress("UNCHECKED_CAST")
                        val list = result as? List<Map<String, Any?>> ?: emptyList()
                        Log.d(TAG, "fetchPoiData '$category' returned ${list.size} items")
                        mainHandler.post { onResult(list) }
                    }
                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.e(TAG, "fetchPoiData error: $code / $msg")
                        mainHandler.post { onResult(emptyList()) }
                    }
                    override fun notImplemented() {
                        Log.w(TAG, "fetchPoiData not implemented on Dart side")
                        mainHandler.post { onResult(emptyList()) }
                    }
                }
            )
        }
    }

    // ── Cleanup ──

    fun dispose() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        listener = null
        Log.d(TAG, "Bridge disposed")
    }
}
