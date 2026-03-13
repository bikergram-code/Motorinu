package com.bikergram.app

import android.app.Activity
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.bikergram.app/filepicker"
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_FILE_REQUEST = 9001

    // ── GPS Bridge (Logcat → Emulator) ───────────────────────────
    // Loggt GPS damit gps_bridge.py die Koordinaten auslesen kann.
    private var gpsManager: LocationManager? = null
    private val gpsListener = LocationListener { loc: Location ->
        Log.d("GpsBridge", "FIX:${loc.latitude},${loc.longitude}")
    }

    // onCreate: Standard-Flutter-Verhalten

    override fun onResume() {
        super.onResume()
        try {
            gpsManager = getSystemService(LOCATION_SERVICE) as LocationManager
            // Sofort letzte bekannte Position loggen (kein Warten auf neuen Fix nötig)
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
                try {
                    gpsManager?.getLastKnownLocation(p)?.let { loc ->
                        Log.d("GpsBridge", "FIX:${loc.latitude},${loc.longitude}")
                    }
                } catch (_: Exception) {}
            }
            // GPS (präzise, braucht Satellit) + Netzwerk (sofort drinnen via WLAN/Mobilfunk)
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
                try { gpsManager?.requestLocationUpdates(p, 2000L, 1f, gpsListener) }
                catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        try { gpsManager?.removeUpdates(gpsListener) } catch (_: Exception) {}
    }

    // Cached Engine verwenden → MainActivity killen zerstört den Engine NICHT
    override fun getCachedEngineId(): String = BikergramApplication.ENGINE_ID

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        android.util.Log.d("MainActivity", "configureFlutterEngine: cached engine verwendet")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickFile") {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                            "application/pdf",
                            "application/msword",
                            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                            "text/plain",
                            "application/zip",
                            "application/x-rar-compressed",
                            "application/gpx+xml",
                            "application/vnd.google-earth.kml+xml",
                            "application/octet-stream"
                        ))
                    }
                    startActivityForResult(intent, PICK_FILE_REQUEST)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PICK_FILE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    val inputStream = contentResolver.openInputStream(uri)
                    val bytes = inputStream?.readBytes() ?: ByteArray(0)
                    inputStream?.close()

                    // Get file name from URI
                    var fileName = "attachment"
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                            if (nameIndex >= 0) {
                                fileName = it.getString(nameIndex)
                            }
                        }
                    }

                    pendingResult?.success(mapOf(
                        "name" to fileName,
                        "bytes" to bytes,
                        "size" to bytes.size
                    ))
                } catch (e: Exception) {
                    pendingResult?.error("FILE_ERROR", e.message, null)
                }
            } else {
                pendingResult?.success(null) // User cancelled
            }
            pendingResult = null
        }
    }
}
