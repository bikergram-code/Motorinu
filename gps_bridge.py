#!/usr/bin/env python3
"""
motorinu GPS Bridge
Liest echte GPS-Koordinaten vom Android-Telefon (GpsBridge Logcat-Tag)
und injiziert sie alle 3 Sekunden in den AAOS-Emulator.

Berechnet Speed + Bearing aus aufeinanderfolgenden Positionen
und übergibt diese an den Emulator → Heading-up funktioniert ohne extra Sensor.

Voraussetzung:
  - motorinu-App auf dem Telefon geöffnet (nicht Android Auto nötig)
  - Telefon GPS aktiviert

Verwendung:
  python gps_bridge.py
"""

import subprocess
import re
import time
import sys
import math

# UTF-8 Output auf Windows erzwingen
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PHONE    = "R58N417DDYX"
EMU      = "emulator-5554"
ADB      = r"C:/Users/pinoi/AppData/Local/Android/sdk/platform-tools/adb.exe"
INTERVAL = 3  # Sekunden

def adb(device, *args):
    try:
        return subprocess.run(
            [ADB, "-s", device, *args],
            capture_output=True, text=True, timeout=10
        )
    except Exception:
        return None

def calc_speed_bearing(lat1, lon1, lat2, lon2, dt_s):
    """
    Berechnet Geschwindigkeit (m/s) und Kurs (0-360°) aus zwei GPS-Punkten.
    Gibt (0.0, 0.0) zurück wenn die Positionen identisch sind.
    """
    R = 6371000  # Erdradius in Metern
    lat1r, lon1r = math.radians(lat1), math.radians(lon1)
    lat2r, lon2r = math.radians(lat2), math.radians(lon2)
    dlat = lat2r - lat1r
    dlon = lon2r - lon1r

    # Haversine-Formel für Distanz
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1r) * math.cos(lat2r) * math.sin(dlon / 2) ** 2
    dist_m = R * 2 * math.asin(math.sqrt(max(0.0, a)))

    if dist_m < 1.0 or dt_s <= 0:
        return 0.0, 0.0

    speed_ms = dist_m / dt_s

    # Anfangskurs (Bearing) 0° = Nord, 90° = Ost
    bearing = math.degrees(math.atan2(
        math.sin(dlon) * math.cos(lat2r),
        math.cos(lat1r) * math.sin(lat2r) - math.sin(lat1r) * math.cos(lat2r) * math.cos(dlon)
    )) % 360

    return speed_ms, bearing

def get_gps_from_logcat():
    """
    Liest GPS vom GpsBridge-Tag (MainActivity.kt).
    Format im Logcat: D GpsBridge: FIX:48.77580,9.18290
    Funktioniert sobald die motorinu-App auf dem Telefon geöffnet ist.
    """
    r = adb(PHONE, "logcat", "-d", "-s", "GpsBridge:D")
    if not r:
        return None
    matches = re.findall(r"FIX:([\d.]+),([\d.]+)", r.stdout)
    if matches:
        lat, lon = matches[-1]
        return float(lat), float(lon)
    return None

def inject_gps(lat, lon, speed_ms=0.0, bearing=0.0):
    """
    Injiziert GPS-Koordinaten + Speed + Bearing in den AAOS-Emulator.
    Format: emu geo fix <lon> <lat> <altitude> <speed_m/s> <bearing_deg>
    """
    adb(EMU, "emu", "geo", "fix",
        f"{lon:.6f}", f"{lat:.6f}", "0",
        f"{speed_ms:.2f}", f"{bearing:.1f}")

def main():
    print("=" * 50)
    print("  motorinu GPS Bridge  [+Speed +Bearing]")
    print("=" * 50)
    print(f"  Telefon  : {PHONE}")
    print(f"  Emulator : {EMU}")
    print(f"  Interval : {INTERVAL}s")
    print(f"\n  Tipp: Öffne die motorinu-App auf dem Telefon,")
    print(f"  dann zeigt der Emulator deinen echten Standort.\n")

    last_coords = None
    last_time   = None
    no_gps_count = 0

    while True:
        coords = get_gps_from_logcat()
        now = time.time()

        if coords:
            lat, lon = coords
            no_gps_count = 0

            speed_ms, bearing = 0.0, 0.0
            if last_coords is not None and last_time is not None:
                dt = now - last_time
                if 0.5 < dt < 30:
                    speed_ms, bearing = calc_speed_bearing(
                        last_coords[0], last_coords[1], lat, lon, dt
                    )

            if coords != last_coords:
                speed_kmh = speed_ms * 3.6
                print(f"  GPS -> lat={lat:.5f}, lon={lon:.5f}  |  {speed_kmh:.1f} km/h  {bearing:.0f}°")
                inject_gps(lat, lon, speed_ms, bearing)
                last_coords = coords
                last_time   = now
        else:
            no_gps_count += 1
            if no_gps_count == 1:
                print("  ... Warte auf GPS vom Telefon...")
            if no_gps_count == 5:
                print("  !! Kein GPS gefunden. Stelle sicher dass:")
                print("     1. GPS am Telefon aktiviert ist")
                print("     2. Die motorinu-App auf dem Telefon geoeffnet ist")
                print("     3. Das Telefon per USB verbunden ist (ADB)")
                no_gps_count = 0

        time.sleep(INTERVAL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nGPS Bridge gestoppt.")
