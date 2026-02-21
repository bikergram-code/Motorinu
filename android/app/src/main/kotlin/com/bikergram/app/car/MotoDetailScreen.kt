package com.bikergram.app.car

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*

/**
 * Detail screen for a single POI (Track, Spot, or Event).
 *
 * Shows:
 * - Title + description text
 * - "Navigieren" button → launches Google Maps with lat/lng
 * - Back button to return to the list
 *
 * Uses PaneTemplate which is allowed for POI category apps.
 */
class MotoDetailScreen(
    carContext: CarContext,
    private val poi: PoiItem
) : Screen(carContext) {

    companion object {
        private const val TAG = "MotoDetail"
    }

    override fun onGetTemplate(): Template {
        Log.d(TAG, "Building detail for: ${poi.title}")

        val paneBuilder = Pane.Builder()

        // Description row
        paneBuilder.addRow(
            Row.Builder()
                .setTitle(poi.title)
                .addText(poi.subtitle)
                .addText(poi.description)
                .build()
        )

        // ── Navigate action → opens Google Maps ──
        paneBuilder.addAction(
            Action.Builder()
                .setTitle("Navigieren")
                .setOnClickListener {
                    Log.d(TAG, "Navigate to: ${poi.title} (${poi.lat}, ${poi.lng})")
                    openGoogleMapsNavigation(poi.lat, poi.lng, poi.title)
                }
                .build()
        )

        return PaneTemplate.Builder(paneBuilder.build())
            .setHeader(Header.Builder()
                .setTitle(poi.title)
                .setStartHeaderAction(Action.BACK)
                .build())
            .build()
    }

    /**
     * Launch Google Maps navigation via Intent.
     *
     * This is the correct way to start navigation from a POI app —
     * we do NOT use NavigationTemplate (that requires NAVIGATION category).
     * Instead we fire a standard geo: intent that Google Maps picks up.
     */
    private fun openGoogleMapsNavigation(lat: Double, lng: Double, label: String) {
        // Strategy: Try multiple approaches to launch navigation
        // 1. startCarApp with google.navigation: (works on most Android Auto setups)
        // 2. startCarApp with geo: URI (fallback for non-Google Maps)

        // Approach 1: Google Maps navigation intent via startCarApp
        try {
            val gmmUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
            val mapIntent = Intent(Intent.ACTION_VIEW, gmmUri).apply {
                setPackage("com.google.android.apps.maps")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            carContext.startCarApp(mapIntent)
            Log.d(TAG, "Google Maps navigation launched for: $label")
            return
        } catch (e: Exception) {
            Log.w(TAG, "startCarApp with Google Maps failed: ${e.message}")
        }

        // Approach 2: Generic geo: URI without package restriction
        try {
            val geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(label)})")
            val geoIntent = Intent(Intent.ACTION_VIEW, geoUri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            carContext.startCarApp(geoIntent)
            Log.d(TAG, "geo: intent launched for: $label")
            return
        } catch (e: Exception) {
            Log.w(TAG, "startCarApp with geo: failed: ${e.message}")
        }

        // Approach 3: Direct startActivity as last resort
        try {
            val gmmUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
            val directIntent = Intent(Intent.ACTION_VIEW, gmmUri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            carContext.startActivity(directIntent)
            Log.d(TAG, "Direct startActivity launched for: $label")
        } catch (e: Exception) {
            Log.e(TAG, "All navigation methods failed for: $label", e)
        }
    }
}
