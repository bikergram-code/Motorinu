package com.bikergram.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.bikergram.app/filepicker"
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_FILE_REQUEST = 9001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Android Auto bridge on the Flutter engine.
        // This makes MotoBridge available to MotoCarAppService even if
        // Android Auto was started before the main activity opened.
        MotoBridge.init(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        android.util.Log.d("MainActivity", "MotoBridge initialized from MainActivity")

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
