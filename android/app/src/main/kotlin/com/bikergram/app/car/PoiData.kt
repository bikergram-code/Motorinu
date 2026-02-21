package com.bikergram.app.car

/**
 * A single Point-of-Interest entry.
 *
 * For the MVP these are hard-coded demo items.
 * Later: fetch from Supabase via Flutter MethodChannel bridge.
 */
data class PoiItem(
    val id: String,
    val title: String,
    val subtitle: String,
    val lat: Double,
    val lng: Double,
    val description: String = ""
)

/**
 * Demo data for each category.
 * Replace with real data from your backend when ready.
 */
object PoiData {

    fun getItems(category: PoiCategory): List<PoiItem> = when (category) {
        PoiCategory.BLITZER -> listOf(
            PoiItem(
                id = "blitzer_1",
                title = "Fester Blitzer B27",
                subtitle = "50 km/h · Stuttgart-Degerloch",
                lat = 48.7452,
                lng = 9.1753,
                description = "Stationärer Blitzer auf der B27 Richtung Tübingen. Tempo 50."
            ),
            PoiItem(
                id = "blitzer_2",
                title = "Mobile Kontrolle A8",
                subtitle = "120 km/h · bei Leonberg",
                lat = 48.7988,
                lng = 9.0153,
                description = "Mobile Geschwindigkeitsmessung auf der A8 Stuttgart–Karlsruhe."
            ),
            PoiItem(
                id = "blitzer_3",
                title = "Ampelblitzer Köln",
                subtitle = "Rotlicht + Tempo · Aachener Str.",
                lat = 50.9413,
                lng = 6.9210,
                description = "Kombinierter Ampel- und Geschwindigkeitsblitzer an der Aachener Straße."
            ),
            PoiItem(
                id = "blitzer_4",
                title = "Polizeikontrolle B500",
                subtitle = "Schwarzwaldhochstraße",
                lat = 48.6616,
                lng = 8.2059,
                description = "Häufige Polizeikontrollen auf der beliebten Bikerstrecke B500."
            ),
            PoiItem(
                id = "blitzer_5",
                title = "Fester Blitzer A3",
                subtitle = "100 km/h · bei Nürnberg",
                lat = 49.4521,
                lng = 11.0767,
                description = "Stationärer Blitzer auf der A3 Richtung Regensburg."
            )
        )
        PoiCategory.TRACKS -> listOf(
            PoiItem(
                id = "track_1",
                title = "Schwarzwaldhochstraße",
                subtitle = "B500 · 60 km · kurvenreich",
                lat = 48.6616,
                lng = 8.2059,
                description = "Legendäre Bikerroute durch den Schwarzwald. Serpentinen, Panorama, top Asphalt."
            ),
            PoiItem(
                id = "track_2",
                title = "Eifel-Nordschleife Runde",
                subtitle = "Nürburgring · 45 km",
                lat = 50.3356,
                lng = 6.9475,
                description = "Rund um die Nordschleife mit Blick auf die Strecke. Biker-Klassiker!"
            ),
            PoiItem(
                id = "track_3",
                title = "Rossfeld Panoramastraße",
                subtitle = "Berchtesgaden · 16 km · Alpenblick",
                lat = 47.6318,
                lng = 13.0583,
                description = "Höchste Panoramastraße Deutschlands. Atemberaubender Alpenblick."
            ),
            PoiItem(
                id = "track_4",
                title = "Mosel-Schleife",
                subtitle = "Cochem–Beilstein · 35 km",
                lat = 50.1459,
                lng = 7.1673,
                description = "Entlang der Mosel durch Weinberge und mittelalterliche Dörfer."
            )
        )

        PoiCategory.SPOTS -> listOf(
            PoiItem(
                id = "spot_1",
                title = "Café Fahrtwind",
                subtitle = "Sauerland · Biker-Treffpunkt",
                lat = 51.3127,
                lng = 8.0200,
                description = "Beliebter Bikertreff im Sauerland. Große Terrasse, guter Kuchen."
            ),
            PoiItem(
                id = "spot_2",
                title = "Adelberg Bikerstop",
                subtitle = "Schwäbische Alb · Aussichtspunkt",
                lat = 48.7639,
                lng = 9.6003,
                description = "Rast mit Panoramablick über die Schwäbische Alb."
            ),
            PoiItem(
                id = "spot_3",
                title = "Nürburgring Paddock",
                subtitle = "Eifel · Rennstrecke",
                lat = 50.3319,
                lng = 6.9417,
                description = "Treffpunkt für Biker am Nürburgring. Tankstelle & Imbiss."
            )
        )

        PoiCategory.EVENTS -> listOf(
            PoiItem(
                id = "event_1",
                title = "Biker-Ausfahrt Schwarzwald",
                subtitle = "Samstag · Treffpunkt: 10 Uhr",
                lat = 48.6616,
                lng = 8.2059,
                description = "Gemeinsame Ausfahrt über die Schwarzwaldhochstraße."
            ),
            PoiItem(
                id = "event_2",
                title = "Motorrad-Treffen Eifel",
                subtitle = "Sonntag · Nürburgring Parking",
                lat = 50.3356,
                lng = 6.9475,
                description = "Saisonstart-Treffen am Nürburgring. Alle Bikes willkommen!"
            ),
            PoiItem(
                id = "event_3",
                title = "Night Ride München",
                subtitle = "Freitag · 21 Uhr · Olympiapark",
                lat = 48.1737,
                lng = 11.5469,
                description = "Nachtfahrt durch München. Treffpunkt am Olympiapark."
            )
        )
    }
}
