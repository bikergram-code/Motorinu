# Changelog

Alle relevanten Änderungen an Motorinu (ehemals Bikergram) werden hier dokumentiert.

## [1.6.4+35] – 2026-04-16

### Neu
- **Gruppenanrufe** (Audio + Video) per LiveKit – mehrere Teilnehmer gleichzeitig
- **Adaptives Video-Grid**: 1 Teilnehmer = Fullscreen, 2 = geteilter Screen, 3+ = 2-Spalten-Grid
- **Eingehender-Anruf-Screen** mit Annehmen / Ablehnen und Ringtone
- **WhatsApp-Style 3-Punkte-Menü** im Nachrichten-Screen (Einstellungen, Neue Gruppe, Verknüpfte Geräte)
- **Verknüpfte-Geräte-Screen** (Platzhalter für zukünftiges Multi-Device-Pairing)
- **Gruppen-Chat anlegen** per neuem Bottom-Sheet
- **Registrierungs-App-Tour** – 6 Slides mit Feature-Überblick nach dem Signup
- **E-Mail-Confirmation-Flow**: "Check your Email"-Banner auf Login nach Registrierung

### Verbessert
- **Chat**: Typing-Indicator, Mic-Button, Online-Status stabilisiert
- **Nachrichten-Screen**: Mehrfach-Auswahl, "Alle gelesen"-Button
- **Navigation**: glattere Kamera-Verfolgung, stabilere Off-Route-Neuberechnung
- **Kompass-Rotation**: tilt-kompensierte Heading auf allen Screens
- **Push-Notifications**: Zustellungs-Fixes für Android (Background + Foreground)
- **Feed-Tabs**: horizontales Wischen auch in Reels + Dating wieder möglich

### Gefixt
- **RLS-Rekursion** auf `group_members` (42P17) – Supabase-Policies entkoppelt
- **Gruppenanruf-Klingeln** auf allen Mitgliedsgeräten (RLS + Realtime Publication)
- **Rides wurden nie gespeichert** (Phantom-Spalte `is_live_go` entfernt)
- **Feed-Tabs hingen** bei Reels / Dating (Gesten-Konflikt gelöst)
- **API-Key-Leak** in Kompass-Screen
- **Play-Store Gerätekompatibilität** (Android-Manifest-Features)
- **Messages-Refresh** nach App-Resume

### Technik
- **REPLICA IDENTITY FULL** auf `calls`-Tabelle für vollständige Realtime-Payloads
- **SECURITY DEFINER Helper** `is_group_member()` umgeht RLS-Rekursion
- **Neue Migrations**: `20260416_calls_group_rls.sql`, `20260416_calls_fix_recursion.sql`, `20260412_add_review_text_to_poi_ratings.sql`, `20260409153403_add_total_km_to_profiles.sql`
- APK-Größen-Optimierung via Proguard-Regeln

---

## [1.6.3+34] – Vorherige Version
Siehe Git-Log: `da31c5b` – Play Store Gerätekompatibilität + Push-Fixes + Messages-Refresh
