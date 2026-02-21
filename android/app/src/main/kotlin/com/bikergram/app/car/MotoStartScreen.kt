package com.bikergram.app.car

import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import androidx.core.graphics.drawable.IconCompat

/**
 * Start screen — shown when the user opens Motorino in Android Auto.
 *
 * Displays four POI categories:
 * - Events (community meetups with date/location from Supabase)
 * - Blitzer & Kontrollen (speed cameras / police from Supabase)
 * - Biker-Spots (meetup locations from Supabase)
 * - Biker-Strecken (scenic routes from Supabase)
 *
 * Each category leads to a sub-list (MotoPoiListScreen) with live data.
 */
class MotoStartScreen(carContext: CarContext) : Screen(carContext) {

    companion object {
        private const val TAG = "MotoStartScreen"
    }

    override fun onGetTemplate(): Template {
        Log.d(TAG, "Building start screen template")

        val listBuilder = ItemList.Builder()

        // Icons for categories
        val eventIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_my_calendar)
        ).build()
        val blitzerIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, android.R.drawable.ic_dialog_alert)
        ).build()
        val spotIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_myplaces)
        ).build()
        val trackIcon = CarIcon.Builder(
            IconCompat.createWithResource(carContext, android.R.drawable.ic_menu_directions)
        ).build()

        // ── Events ──
        listBuilder.addItem(
            Row.Builder()
                .setTitle("Events")
                .addText("Biker-Treffen & Veranstaltungen")
                .setImage(eventIcon)
                .setBrowsable(true)
                .setOnClickListener {
                    Log.d(TAG, "Category: Events")
                    screenManager.push(MotoPoiListScreen(carContext, PoiCategory.EVENTS))
                }
                .build()
        )

        // ── Blitzer ──
        listBuilder.addItem(
            Row.Builder()
                .setTitle("Blitzer & Kontrollen")
                .addText("Aktuelle Meldungen in deiner Nähe")
                .setImage(blitzerIcon)
                .setBrowsable(true)
                .setOnClickListener {
                    Log.d(TAG, "Category: Blitzer → Map Screen")
                    screenManager.push(MotoBlitzerMapScreen(carContext))
                }
                .build()
        )

        // ── Biker-Spots ──
        listBuilder.addItem(
            Row.Builder()
                .setTitle("Biker-Spots")
                .addText("Treffpunkte, Cafés & Tankstellen")
                .setImage(spotIcon)
                .setBrowsable(true)
                .setOnClickListener {
                    Log.d(TAG, "Category: Spots")
                    screenManager.push(MotoPoiListScreen(carContext, PoiCategory.SPOTS))
                }
                .build()
        )

        // ── Biker-Strecken ──
        listBuilder.addItem(
            Row.Builder()
                .setTitle("Biker-Strecken")
                .addText("Schöne Routen von der Community")
                .setImage(trackIcon)
                .setBrowsable(true)
                .setOnClickListener {
                    Log.d(TAG, "Category: Tracks")
                    screenManager.push(MotoPoiListScreen(carContext, PoiCategory.TRACKS))
                }
                .build()
        )

        return ListTemplate.Builder()
            .setHeader(Header.Builder()
                .setTitle("Motorino")
                .setStartHeaderAction(Action.APP_ICON)
                .build())
            .setSingleList(listBuilder.build())
            .build()
    }
}
