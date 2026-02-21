package com.bikergram.app.car

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import com.bikergram.app.MotoBridge

/**
 * Blitzer map screen — shows speed cameras / police controls on a system-rendered map.
 *
 * Uses PlaceListMapTemplate which displays a list of places with markers on a map.
 * The map is rendered by the system (Google Maps) — no custom SurfaceCallback needed.
 * This keeps the app in the POI category (no NAVIGATION category required).
 *
 * Data flow:
 * 1. MotoBridge.fetchPoiData("blitzer") → Dart MethodChannel → Supabase
 * 2. Supabase returns blitzer_reports (is_active=true)
 * 3. Each report becomes a PlaceMarker on the map (red markers)
 * 4. Tap a marker → MotoDetailScreen → "Navigieren" → Google Maps
 *
 * Fallback: If no live data, shows demo Blitzer from PoiData.
 */
class MotoBlitzerMapScreen(
    carContext: CarContext
) : Screen(carContext) {

    companion object {
        private const val TAG = "MotoBlitzerMap"
        private const val MAX_RETRIES = 5
        private const val RETRY_DELAY_MS = 2000L
        /** Android Auto PlaceListMapTemplate supports max 6 items */
        private const val MAX_ITEMS = 6
    }

    private var isLoading = true
    private var items: List<PoiItem> = emptyList()
    private var errorMessage: String? = null
    private var retryCount = 0
    private var activeRequestId = 0
    private val handler = Handler(Looper.getMainLooper())

    init {
        loadData()
    }

    private fun loadData() {
        handler.removeCallbacksAndMessages(null)
        val requestId = ++activeRequestId
        isLoading = true
        errorMessage = null
        invalidate()

        if (!MotoBridge.isInitialized) {
            if (retryCount < MAX_RETRIES) {
                retryCount++
                Log.w(TAG, "MotoBridge not ready, retry $retryCount/$MAX_RETRIES in ${RETRY_DELAY_MS}ms")
                handler.postDelayed({ loadData() }, RETRY_DELAY_MS)
                return
            }
            // After all retries, fall back to demo data
            Log.w(TAG, "MotoBridge never became ready — showing demo Blitzer data")
            items = PoiData.getItems(PoiCategory.BLITZER)
            isLoading = false
            invalidate()
            return
        }

        retryCount = 0
        Log.d(TAG, "Fetching blitzer data from Supabase via MotoBridge")

        MotoBridge.fetchPoiData(
            category = "blitzer",
            onResult = { result ->
                if (requestId != activeRequestId) {
                    Log.d(TAG, "Ignoring stale result for request=$requestId")
                    return@fetchPoiData
                }
                Log.d(TAG, "Got ${result.size} blitzer items")
                items = result.mapNotNull { map ->
                    try {
                        PoiItem(
                            id = map["id"] as? String ?: "",
                            title = map["title"] as? String ?: "Blitzer",
                            subtitle = map["subtitle"] as? String ?: "",
                            lat = (map["lat"] as? Number)?.toDouble() ?: 0.0,
                            lng = (map["lng"] as? Number)?.toDouble() ?: 0.0,
                            description = map["description"] as? String ?: ""
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse blitzer item: $e")
                        null
                    }
                }
                if (items.isEmpty()) {
                    val demoItems = PoiData.getItems(PoiCategory.BLITZER)
                    if (demoItems.isNotEmpty()) {
                        Log.d(TAG, "Supabase returned empty — using ${demoItems.size} demo blitzer items")
                        items = demoItems
                    } else {
                        errorMessage = "Keine Blitzer in der Nähe"
                    }
                }
                isLoading = false
                invalidate()
            }
        )

        handler.postDelayed({
            if (requestId != activeRequestId || !isLoading) return@postDelayed
            Log.w(TAG, "Blitzer fetch timeout — showing fallback data")
            val demoItems = PoiData.getItems(PoiCategory.BLITZER)
            if (demoItems.isNotEmpty()) {
                items = demoItems
            } else {
                errorMessage = "Blitzer-Daten konnten nicht geladen werden"
            }
            isLoading = false
            invalidate()
        }, 8000L)
    }

    override fun onGetTemplate(): Template {
        // ── Loading state ──
        if (isLoading) {
            val loadingMsg = if (retryCount > 0)
                "Verbinde mit App... ($retryCount/$MAX_RETRIES)"
            else
                "Blitzer & Kontrollen"

            // PlaceListMapTemplate doesn't support setLoading, so show a simple list while loading
            return ListTemplate.Builder()
                .setHeader(Header.Builder()
                    .setTitle(loadingMsg)
                    .setStartHeaderAction(Action.BACK)
                    .build())
                .setLoading(true)
                .build()
        }

        // ── Error state (no items at all) ──
        if (errorMessage != null || items.isEmpty()) {
            val msg = errorMessage ?: "Keine Blitzer-Daten verfügbar"
            val listBuilder = ItemList.Builder()
            listBuilder.setNoItemsMessage(msg)
            return ListTemplate.Builder()
                .setHeader(Header.Builder()
                    .setTitle("Blitzer & Kontrollen")
                    .setStartHeaderAction(Action.BACK)
                    .build())
                .setSingleList(listBuilder.build())
                .build()
        }

        // ── Map with Blitzer markers ──
        Log.d(TAG, "Building PlaceListMapTemplate with ${items.size} blitzer markers")

        val itemListBuilder = ItemList.Builder()

        for (item in items.take(MAX_ITEMS)) {
            itemListBuilder.addItem(
                Row.Builder()
                    .setTitle(item.title)
                    .addText(item.subtitle)
                    .setBrowsable(true)
                    .setMetadata(
                        Metadata.Builder()
                            .setPlace(
                                Place.Builder(
                                    CarLocation.create(item.lat, item.lng)
                                ).setMarker(
                                    PlaceMarker.Builder()
                                        .setColor(CarColor.RED)
                                        .build()
                                ).build()
                            ).build()
                    )
                    .setOnClickListener {
                        Log.d(TAG, "Selected blitzer: ${item.title}")
                        screenManager.push(MotoDetailScreen(carContext, item))
                    }
                    .build()
            )
        }

        val refreshAction = Action.Builder()
            .setTitle("Aktualisieren")
            .setOnClickListener {
                Log.d(TAG, "Manual refresh requested")
                loadData()
            }
            .build()

        val templateBuilder = PlaceListMapTemplate.Builder()
            .setTitle("Blitzer & Kontrollen")
            .setHeaderAction(Action.BACK)
            .setActionStrip(
                ActionStrip.Builder()
                    .addAction(refreshAction)
                    .build()
            )
            .setItemList(itemListBuilder.build())
            .setCurrentLocationEnabled(true) // Host shows current location + loads map tiles

        // Set anchor to first item — gives the host a camera center to load tiles around
        if (items.isNotEmpty()) {
            templateBuilder.setAnchor(
                Place.Builder(
                    CarLocation.create(items.first().lat, items.first().lng)
                ).setMarker(
                    PlaceMarker.Builder().build()
                ).build()
            )
            Log.d(TAG, "Anchor set to: ${items.first().title} (${items.first().lat}, ${items.first().lng})")
        }

        return templateBuilder.build()
    }
    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
    }

}
