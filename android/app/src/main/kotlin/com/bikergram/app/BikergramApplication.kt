package com.bikergram.app

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.maplibre.android.MapLibre

/**
 * Custom Application class that pre-warms the Flutter engine.
 *
 * Engine im Application-Context starten → lebt unabhängig von Activities.
 */
class BikergramApplication : Application() {

    companion object {
        const val ENGINE_ID = "bikergram_main_engine"
        private const val TAG = "BikergramApp"
    }

    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        prewarmFlutterEngine()
    }

    private fun prewarmFlutterEngine() {
        try {
            val engine = FlutterEngine(this)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            Log.d(TAG, "Flutter Engine vorgewärmt")
        } catch (e: Exception) {
            Log.e(TAG, "Flutter Engine Vorwärmen fehlgeschlagen: $e")
        }
    }
}
