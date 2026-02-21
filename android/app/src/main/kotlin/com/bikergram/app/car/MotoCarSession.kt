package com.bikergram.app.car

import android.content.Intent
import android.util.Log
import androidx.car.app.Screen
import androidx.car.app.Session

/**
 * Android Auto session for the Motorino POI app.
 *
 * Each connection to a car display creates one session.
 * The start screen shows a list of categories (Tracks, Spots, Events).
 */
class MotoCarSession : Session() {

    companion object {
        private const val TAG = "MotoCarSession"
    }

    override fun onCreateScreen(intent: Intent): Screen {
        Log.d(TAG, "Creating start screen")
        return MotoStartScreen(carContext)
    }
}
