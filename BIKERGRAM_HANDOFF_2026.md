# BIKERGRAM – Handoff / Projekt-Überblick (Stand: 28.01.2026)

## 1) Kurzüberblick
Bikergram besteht aktuell aus:
- **Flutter App** (Mobile + Web)
- **PHP API (VPS)** unter `api.bikergram.com`
- **MariaDB** auf dem VPS
- **Nginx + PHP-FPM** als Webserver/Runtime

Ziel: Schnell MVP launchen (Onboarding + Basis-Feed + GPS/Map + Garage) und danach skalieren.

---

## 2) Server / Domains
### Production API
- **Domain:** `api.bikergram.com`
- **A-Record:** `152.53.255.4`
- **TLS:** Let's Encrypt (R13)

### SSH (VPS)
- **User:** `bikergram`
- **Host:** (VPS Hostname) `v2202601329793428180`
- **Wichtig:** Port kann bei dir **2222** sein (ssh.bikergram.com), je nach Setup.

> Hinweis: Wenn SSH per Key nicht klappt, prüfe immer: richtiger Host, richtiger Port, richtige Identity-Datei.

---

## 3) Nginx / PHP
### Nginx Sites
- Aktiv über Symlink:
  - `/etc/nginx/sites-enabled/bikergram-api -> /etc/nginx/sites-available/bikergram-api`

### TLS Zertifikat (API)
- Zertifikat:
  - `/etc/letsencrypt/live/api.bikergram.com/fullchain.pem`
- Key:
  - `/etc/letsencrypt/live/api.bikergram.com/privkey.pem`

### Document Root
- `/var/www/bikergram-api`

### PHP-FPM
- Typisch (Ubuntu):
  - Socket: `/run/php/php8.1-fpm.sock`

---

## 4) API-Endpunkte (PHP)
### Health
- `GET /health.php`
  - Response: `OK`

### Registrierung
- `POST /register.php`
- JSON Body:
  - `email` (string)
  - `password` (string)
  - optional: `username` (string)

### Login
- `POST /login.php`
- JSON Body:
  - `email` (string)
  - `password` (string)

### Me
- `GET /me.php`
- Header:
  - `Authorization: Bearer <accessToken>`

### Bikername
- `POST /bikername_generate.php`
- `POST /bikername_check.php`
- `POST /bikername_reserve.php`

---

## 5) Datenbank (MariaDB)
### Config
- Datei:
  - `/var/www/bikergram-api/config.php`
- Inhalt (Beispiel):
  - `db_host`, `db_name`, `db_user`, `db_pass`

⚠️ **Wichtig:** `db_pass` muss auf dem VPS als MariaDB-User-Passwort gesetzt sein.

### DB Name
- `bikergram`

### Tabellen (aktuell)
- `users`
  - `id`, `email`, `username`, `pass_hash`, `created_at`
- `sessions`
- `auth_tokens`
- `bikername_reservations`

---

## 6) Flutter – API Konfiguration
### Base URL
Standard ist:
- `https://api.bikergram.com`

Override möglich per:
- `--dart-define=BIKERGRAM_API_BASE_URL=https://api.bikergram.com`

### Token Storage
- Tokens werden gespeichert über `AuthTokenStore`:
  - Mobile/Desktop: **flutter_secure_storage**
  - Web: Fallback via **SharedPreferences**

---

## 7) Smoke-Tests (Server-Terminal per SSH)
### API erreichbar?
```bash
curl -s https://api.bikergram.com/health.php ; echo
```

### Registrierung + Login + Me
```bash
curl -sS -X POST https://api.bikergram.com/register.php \
  -H "Content-Type: application/json" \
  -d '{"email":"test1@example.com","password":"SuperSecret123"}' ; echo

LOGIN_JSON="$(curl -sS -X POST https://api.bikergram.com/login.php \
  -H "Content-Type: application/json" \
  -d '{"email":"test1@example.com","password":"SuperSecret123"}')"

ACCESS="$(php -r '$j=json_decode(stream_get_contents(STDIN),true); echo $j["data"]["tokens"]["accessToken"] ?? "";' <<< "$LOGIN_JSON")"

curl -sS https://api.bikergram.com/me.php -H "Authorization: Bearer $ACCESS" ; echo
```

---

## 8) Typische Fehlerbilder
### 500 bei register/login
- In Nginx error.log prüfen:
  - `/var/log/nginx/error.log`
- Häufig:
  - DB Schema passt nicht zum PHP Code (z.B. `password_hash` vs `pass_hash`)
  - falsches DB Passwort in `config.php`

### Zertifikat stimmt lokal, aber extern nicht
- Prüfen welcher Nginx vHost wirklich matched (`server_name`) und ob `sites-enabled` korrekt.

