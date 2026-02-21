# Bikergram – Netcup Backend Check

Dieses Paket hilft dir zu prüfen, ob dein Backend (API) + Datenbank (MySQL/phpMyAdmin) bereit sind, damit **"Profil abschließen"** wirklich speichern und danach **ohne Zurück** in den App-Teil 2 weiterleiten kann.

## 1) API Smoke Test

### Voraussetzung
- `curl` installiert (Windows: Git Bash / WSL / macOS/Linux Terminal)

### Ausführen

```bash
bash netcup_api_smoke_test.sh
```

**Hinweis:** Das Script nutzt deine Domain `https://www.bikergram.de/api`.
Wenn du stattdessen `https://bikergram.de/api` nutzt, ändere `BASE_URL` im Script.

## 2) Minimal-DB Schema

Wenn du die API-Endpunkte **serverseitig bereits hast**, brauchst du dieses Schema nicht.
Wenn du aber noch Tabellen anlegen musst (phpMyAdmin), importiere:

- `bikergram_min_schema.sql`

**Achtung:** Das ist ein *Minimal-Schema*, das zu den in deinem Flutter-Core erwarteten Endpoints passt:
- `/profile/draft/start`
- `/profile/draft/{id}`
- `/profile/draft/{id}/step/{step}`
- `/profile/draft/{id}/submit`
- `/upload/profile-image`
- `/api/bikername_check.php` etc.

Du kannst später normalisieren (Badges/XPs in eigene Tabellen), aber für den Start reicht auch JSON.
