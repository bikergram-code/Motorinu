# Backend (NestJS) Client – Flutter

Diese Dateien verbinden dein Flutter-Projekt mit dem NestJS Backend (`bikergram-backend`).

## Base URL
- DEV (Handy/Tablet im WLAN): `http://192.168.0.84:3000`
- PROD (später VPS): `https://api.bikergram.com`

Stell das in `core/api_config.dart` ein.

## Quick test (im Code)
```dart
import 'core/backend/backend_exports.dart';

final api = BackendBootstrap.api;
final health = await api.health();
print(health);
```

## Auth
- `register(...)` / `login(...)` speichern Tokens automatisch (SharedPreferences)
- `me()` holt Profil
- `logout()` leert Tokens

Hinweis: Für echte Android-Geräte im DEV kann HTTP geblockt sein.
Wenn du Probleme bekommst, setz in `android/app/src/main/AndroidManifest.xml` im `<application>`:
`android:usesCleartextTraffic="true"`
