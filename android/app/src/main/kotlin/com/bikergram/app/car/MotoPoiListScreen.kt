package com.bikergram.app.car

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import com.bikergram.app.MotoBridge

/**
 * Shows a list of POIs for a given category (Events / Blitzer / Spots).
 *
 * Data is fetched live from Supabase via the Flutter MethodChannel bridge.
 * If the bridge isn't ready yet (app cold-started by Android Auto), retries
 * up to 5 times with 2-second intervals before falling back to demo data.
 */
class MotoPoiListScreen(
    carContext: CarContext,
    private val category: PoiCategory
) : Screen(carContext) {

    companion object {
        private const val TAG = "MotoPoiList"
        private const val MAX_RETRIES = 5
        private const val RETRY_DELAY_MS = 2000L
    }

    private var isLoading = true
    private var items: List<PoiItem> = emptyList()
    private var errorMessage: String? = null
    private var retryCount = 0
    private val handler = Handler(Looper.getMainLooper())

    init {
        loadData()
    }

    private fun loadData() {
        isLoading = true
        errorMessage = null
        invalidate()

        val dartCategory = when (category) {
            PoiCategory.EVENTS -> "events"
            PoiCategory.BLITZER -> "blitzer"
            PoiCategory.SPOTS -> "spots"
            PoiCategory.TRACKS -> "spots"
        }

        if (!MotoBridge.isInitialized) {
            if (retryCount < MAX_RETRIES) {
                retryCount++
                Log.w(TAG, "MotoBridge not ready, retry $retryCount/$MAX_RETRIES in ${RETRY_DELAY_MS}ms")
                handler.postDelayed({ loadData() }, RETRY_DELAY_MS)
                return
            }
            // After all retries, fall back to demo data
            Log.w(TAG, "MotoBridge never became ready — showing demo data")
            items = PoiData.getItems(category)
            isLoading = false
            invalidate()
            return
        }

        retryCount = 0
        Log.d(TAG, "Fetching $dartCategory from Supabase via MotoBridge")

        MotoBridge.fetchPoiData(
            category = dartCategory,
            onResult = { result ->
                Log.d(TAG, "Got ${result.size} items for $dartCategory")
                items = result.mapNotNull { map ->
                    try {
                        PoiItem(
                            id = map["id"] as? String ?: "",
                            title = map["title"] as? String ?: "Unbekannt",
                            subtitle = map["subtitle"] as? String ?: "",
                            lat = (map["lat"] as? Number)?.toDouble() ?: 0.0,
                            lng = (map["lng"] as? Number)?.toDouble() ?: 0.0,
                            description = map["description"] as? String ?: ""
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse POI item: $e")
                        null
                    }
                }
                if (items.isEmpty()) {
                    // Fallback to demo data when Supabase returns empty
                    val demoItems = PoiData.getItems(category)
                    if (demoItems.isNotEmpty()) {
                        Log.d(TAG, "Supabase returned empty — using ${demoItems.size} demo items")
                        items = demoItems
                    } else {
                        errorMessage = when (category) {
                            PoiCategory.EVENTS -> "Keine bevorstehenden Events"
                            PoiCategory.BLITZER -> "Keine Blitzer in der Nähe"
                            PoiCategory.SPOTS -> "Keine Spots verfügbar"
                            PoiCategory.TRACKS -> "Keine Strecken verfügbar"
                        }
                    }
                }
                isLoading = false
                invalidate()
            }
        )
    }

    override fun onGetTemplate(): Template {
        if (isLoading) {
            val loadingMsg = if (retryCount > 0)
                "Verbinde mit App... ($retryCount/$MAX_RETRIES)"
            else
                category.displayName

            return ListTemplate.Builder()
                .setHeader(Header.Builder()
                    .setTitle(loadingMsg)
                    .setStartHeaderAction(Action.BACK)
                    .build())
                .setLoading(true)
                .build()
        }

        if (errorMessage != null || items.isEmpty()) {
            val msg = errorMessage ?: "Keine Daten verfügbar"
            val listBuilder = ItemList.Builder()
            listBuilder.setNoItemsMessage(msg)
            return ListTemplate.Builder()
                .setHeader(Header.Builder()
                    .setTitle(category.displayName)
                    .setStartHeaderAction(Action.BACK)
                    .build())
                .setSingleList(listBuilder.build())
                .build()
        }

        Log.d(TAG, "Building list for ${category.displayName}: ${items.size} items")
        val listBuilder = ItemList.Builder()
        for (item in items.take(6)) {
            listBuilder.addItem(
                Row.Builder()
                    .setTitle(item.title)
                    .addText(item.subtitle)
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "Selected: ${item.title}")
                        screenManager.push(MotoDetailScreen(carContext, item))
                    }
                    .build()
            )
        }

        return ListTemplate.Builder()
            .setHeader(Header.Builder()
                .setTitle(category.displayName)
                .setStartHeaderAction(Action.BACK)
                .build())
            .setSingleList(listBuilder.build())
            .build()
    }
}
