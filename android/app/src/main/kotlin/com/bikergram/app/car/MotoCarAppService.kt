package com.bikergram.app.car

import android.util.Log
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.validation.HostValidator
import com.bikergram.app.MotoBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Entry point for Android Auto.
 *
 * Category: POI (Points of Interest)
 * Shows Events, Blitzer, Spots from the Motorino / Bikergram community.
 * Data is loaded live from Supabase via the Flutter MethodChannel.
 *
 * If the main Flutter engine (from MainActivity) is already running,
 * MotoBridge will already be initialized and we reuse it.
 * Otherwise we start a background Flutter engine to enable MethodChannel.
 */
class MotoCarAppService : CarAppService() {

    companion object {
        private const val TAG = "MotoCarApp"
        private var backgroundEngine: FlutterEngine? = null
    }

    override fun createHostValidator(): HostValidator {
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "MotoCarAppService onCreate")
        ensureFlutterEngineReady()
    }

    /**
     * Ensure the MotoBridge MethodChannel is available.
     * If MainActivity already initialized it, this is a no-op.
     * Otherwise we spin up a background Flutter engine.
     */
    private fun ensureFlutterEngineReady() {
        if (MotoBridge.isInitialized) {
            Log.d(TAG, "MotoBridge already initialized (main engine running)")
            return
        }

        Log.d(TAG, "MotoBridge not initialized — starting background Flutter engine")
        try {
            if (backgroundEngine == null) {
                val engine = FlutterEngine(applicationContext)
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
                MotoBridge.init(engine.dartExecutor.binaryMessenger, applicationContext)
                backgroundEngine = engine
                Log.d(TAG, "Background Flutter engine started and MotoBridge initialized")
            } else {
                Log.d(TAG, "Reusing existing background Flutter engine")
                if (!MotoBridge.isInitialized) {
                    MotoBridge.init(backgroundEngine!!.dartExecutor.binaryMessenger, applicationContext)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start background Flutter engine: $e")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "MotoCarAppService onDestroy")
        // Don't destroy the background engine here — it might be reused.
        // It will be GC'd naturally when the process ends.
    }

    @Suppress("deprecation")
    override fun onCreateSession(): Session {
        Log.d(TAG, "Creating Android Auto session (legacy onCreateSession)")
        ensureFlutterEngineReady()
        return MotoCarSession()
    }

    override fun onCreateSession(sessionInfo: SessionInfo): Session {
        Log.d(TAG, "Creating Android Auto session (displayType=${sessionInfo.displayType})")
        ensureFlutterEngineReady()
        return MotoCarSession()
    }
}
