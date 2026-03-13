// ignore_for_file: avoid_print
/// Seed script: Insert 2026 motorsport events into Supabase.
///
/// Usage:
///   dart run scripts/seed_motorsport_events.dart
///
/// Requires environment or will use hardcoded Supabase credentials.
/// Events are tagged with community: 'bikergram' (bikes) or 'motorgram' (cars).

import 'dart:convert';
import 'package:http/http.dart' as http;

const supabaseUrl = 'https://trmwbkpfafigraveneva.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRybXdia3BmYWZpZ3JhdmVuZXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExMDYyODMsImV4cCI6MjA4NjY4MjI4M30.aUyG0Pn0dTv68jVXBXZpGgwumaiVNOQo96t-i-sL-w8';

/// We need a real authenticated user to create events.
/// You'll need to set these or login first.
const userEmail = ''; // fill in
const userPassword = ''; // fill in

Future<String?> login() async {
  if (userEmail.isEmpty || userPassword.isEmpty) {
    print('ERROR: Set userEmail and userPassword in the script!');
    print('       Or run the SQL seed below directly in Supabase Dashboard.');
    return null;
  }
  final res = await http.post(
    Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': userEmail, 'password': userPassword}),
  );
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    return data['access_token'] as String;
  }
  print('Login failed: ${res.statusCode} ${res.body}');
  return null;
}

Future<void> insertEvents(String token, List<Map<String, dynamic>> events) async {
  int success = 0;
  int failed = 0;

  for (final event in events) {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/events'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(event),
    );
    if (res.statusCode == 201) {
      success++;
      print('  [OK] ${event['title']}');
    } else {
      failed++;
      print('  [FAIL] ${event['title']}: ${res.statusCode} ${res.body}');
    }
  }
  print('\nDone: $success success, $failed failed');
}

void main() async {
  // ──────────────────────────────────────────────────
  // Since the script needs auth, let's just print SQL
  // that can be pasted into Supabase Dashboard SQL Editor.
  // ──────────────────────────────────────────────────
  printSqlSeed();
}

void printSqlSeed() {
  print('''
-- ═══════════════════════════════════════════════════════════════
-- STEP 1: Add missing columns (run this FIRST)
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE events ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'meetup';
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;

-- Storage bucket for event images
INSERT INTO storage.buckets (id, name, public)
VALUES ('events', 'events', true)
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- STEP 2: Create a system user for official events (or use existing admin)
-- ═══════════════════════════════════════════════════════════════
-- We'll use the first admin user in the system. Adjust user_id below!
-- Find your admin user_id with: SELECT id FROM auth.users LIMIT 1;

-- ═══════════════════════════════════════════════════════════════
-- STEP 3: Insert all motorsport events
-- ═══════════════════════════════════════════════════════════════

DO \$\$
DECLARE
  system_user_id UUID;
BEGIN
  -- Get first user as system user (replace with your admin UUID if needed)
  SELECT id INTO system_user_id FROM auth.users ORDER BY created_at ASC LIMIT 1;

  IF system_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found! Create a user first.';
  END IF;

  -- ═══════════════════════════════════════════════════
  -- MOTOGP 2026 (community = 'bikergram', category = 'race')
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, 'MotoGP - Thai GP', 'Round 1 - Chang International Circuit', 'Buriram, Thailand', '2026-03-01 14:00:00+00', '2026-03-01 16:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Brazilian GP', 'Round 2 - Autodromo Ayrton Senna, Goiania', 'Goiania, Brasilien', '2026-03-22 19:00:00+00', '2026-03-22 21:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Americas GP', 'Round 3 - Circuit of the Americas', 'Austin, USA', '2026-03-29 20:00:00+00', '2026-03-29 22:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Qatar GP', 'Round 4 - Lusail International Circuit (Nachtrennen)', 'Lusail, Katar', '2026-04-12 18:00:00+00', '2026-04-12 20:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Spanish GP', 'Round 5 - Circuito de Jerez - Angel Nieto', 'Jerez, Spanien', '2026-04-26 13:00:00+00', '2026-04-26 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - French GP', 'Round 6 - Circuit Bugatti, Le Mans', 'Le Mans, Frankreich', '2026-05-10 13:00:00+00', '2026-05-10 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Catalan GP', 'Round 7 - Circuit de Barcelona-Catalunya', 'Barcelona, Spanien', '2026-05-17 13:00:00+00', '2026-05-17 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Italian GP', 'Round 8 - Autodromo del Mugello', 'Mugello, Italien', '2026-05-31 13:00:00+00', '2026-05-31 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Hungarian GP', 'Round 9 - Balaton Park Circuit', 'Balatonfured, Ungarn', '2026-06-07 13:00:00+00', '2026-06-07 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Czech GP', 'Round 10 - Automotodrom Brno', 'Brno, Tschechien', '2026-06-21 13:00:00+00', '2026-06-21 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Dutch TT', 'Round 11 - TT Circuit Assen', 'Assen, Niederlande', '2026-06-28 13:00:00+00', '2026-06-28 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - German GP', 'Round 12 - Sachsenring', 'Hohenstein-Ernstthal, Deutschland', '2026-07-12 13:00:00+00', '2026-07-12 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - British GP', 'Round 13 - Silverstone Circuit', 'Silverstone, England', '2026-08-09 13:00:00+00', '2026-08-09 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Aragon GP', 'Round 14 - MotorLand Aragon', 'Alcaniz, Spanien', '2026-08-30 13:00:00+00', '2026-08-30 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - San Marino GP', 'Round 15 - Misano World Circuit Marco Simoncelli', 'Misano Adriatico, Italien', '2026-09-13 13:00:00+00', '2026-09-13 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Austrian GP', 'Round 16 - Red Bull Ring', 'Spielberg, Oesterreich', '2026-09-20 13:00:00+00', '2026-09-20 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Japanese GP', 'Round 17 - Mobility Resort Motegi', 'Motegi, Japan', '2026-10-04 06:00:00+00', '2026-10-04 08:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Indonesian GP', 'Round 18 - Pertamina Mandalika Circuit', 'Lombok, Indonesien', '2026-10-11 08:00:00+00', '2026-10-11 10:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Australian GP', 'Round 19 - Phillip Island Grand Prix Circuit', 'Phillip Island, Australien', '2026-10-25 04:00:00+00', '2026-10-25 06:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Malaysian GP', 'Round 20 - Sepang International Circuit', 'Sepang, Malaysia', '2026-11-01 08:00:00+00', '2026-11-01 10:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Portuguese GP', 'Round 21 - Autodromo Internacional do Algarve', 'Portimao, Portugal', '2026-11-15 14:00:00+00', '2026-11-15 16:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'MotoGP - Valencia GP', 'Round 22 - Circuit Ricardo Tormo (Saisonfinale)', 'Valencia, Spanien', '2026-11-22 14:00:00+00', '2026-11-22 16:00:00+00', 'race', 'bikergram', true);

  -- ═══════════════════════════════════════════════════
  -- WSBK 2026 (community = 'bikergram', category = 'race')
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, 'WSBK - Phillip Island', 'Round 1 - Phillip Island Grand Prix Circuit', 'Phillip Island, Australien', '2026-02-22 04:00:00+00', '2026-02-22 06:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Portimao', 'Round 2 - Autodromo Internacional do Algarve', 'Portimao, Portugal', '2026-03-29 14:00:00+00', '2026-03-29 16:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Assen', 'Round 3 - TT Circuit Assen', 'Assen, Niederlande', '2026-04-19 13:00:00+00', '2026-04-19 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Balaton Park', 'Round 4 - Balaton Park Circuit', 'Balatonfured, Ungarn', '2026-05-03 13:00:00+00', '2026-05-03 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Most', 'Round 5 - Autodrom Most', 'Most, Tschechien', '2026-05-17 13:00:00+00', '2026-05-17 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Aragon', 'Round 6 - MotorLand Aragon', 'Alcaniz, Spanien', '2026-05-31 13:00:00+00', '2026-05-31 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Misano', 'Round 7 - Misano World Circuit Marco Simoncelli', 'Misano Adriatico, Italien', '2026-06-14 13:00:00+00', '2026-06-14 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Donington Park', 'Round 8 - Donington Park', 'Castle Donington, England', '2026-07-12 13:00:00+00', '2026-07-12 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Magny-Cours', 'Round 9 - Circuit de Nevers Magny-Cours', 'Magny-Cours, Frankreich', '2026-09-06 13:00:00+00', '2026-09-06 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Cremona', 'Round 10 - Cremona Circuit', 'Cremona, Italien', '2026-09-27 13:00:00+00', '2026-09-27 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Estoril', 'Round 11 - Circuito do Estoril', 'Estoril, Portugal', '2026-10-11 13:00:00+00', '2026-10-11 15:00:00+00', 'race', 'bikergram', true),
  (system_user_id, 'WSBK - Jerez', 'Round 12 - Circuito de Jerez (Saisonfinale)', 'Jerez, Spanien', '2026-10-18 13:00:00+00', '2026-10-18 15:00:00+00', 'race', 'bikergram', true);

  -- ═══════════════════════════════════════════════════
  -- ISLE OF MAN TT 2026 (community = 'bikergram', category = 'race')
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, 'Isle of Man TT 2026', 'Das legendaere Strassenrennen auf der Isle of Man. Practice Week + Race Week.', 'Isle of Man, England', '2026-05-25 09:00:00+00', '2026-06-06 18:00:00+00', 'race', 'bikergram', true);

  -- ═══════════════════════════════════════════════════
  -- FORMULA 1 2026 (community = 'motorgram', category = 'race')
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, 'F1 - Australian GP', 'Round 1 - Albert Park Circuit', 'Melbourne, Australien', '2026-03-08 06:00:00+00', '2026-03-08 08:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Chinese GP', 'Round 2 - Shanghai International Circuit (Sprint)', 'Shanghai, China', '2026-03-15 07:00:00+00', '2026-03-15 09:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Japanese GP', 'Round 3 - Suzuka Circuit', 'Suzuka, Japan', '2026-03-29 06:00:00+00', '2026-03-29 08:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Bahrain GP', 'Round 4 - Bahrain International Circuit', 'Sakhir, Bahrain', '2026-04-12 15:00:00+00', '2026-04-12 17:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Saudi Arabian GP', 'Round 5 - Jeddah Corniche Circuit', 'Jeddah, Saudi-Arabien', '2026-04-19 17:00:00+00', '2026-04-19 19:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Miami GP', 'Round 6 - Miami International Autodrome (Sprint)', 'Miami, USA', '2026-05-03 20:00:00+00', '2026-05-03 22:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Canadian GP', 'Round 7 - Circuit Gilles Villeneuve (Sprint)', 'Montreal, Kanada', '2026-05-24 18:00:00+00', '2026-05-24 20:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Monaco GP', 'Round 8 - Circuit de Monaco', 'Monte Carlo, Monaco', '2026-06-07 13:00:00+00', '2026-06-07 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Spanish GP', 'Round 9 - Circuit de Barcelona-Catalunya', 'Barcelona, Spanien', '2026-06-14 13:00:00+00', '2026-06-14 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Austrian GP', 'Round 10 - Red Bull Ring', 'Spielberg, Oesterreich', '2026-06-28 13:00:00+00', '2026-06-28 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - British GP', 'Round 11 - Silverstone Circuit (Sprint)', 'Silverstone, England', '2026-07-05 14:00:00+00', '2026-07-05 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Belgian GP', 'Round 12 - Circuit de Spa-Francorchamps', 'Spa, Belgien', '2026-07-19 14:00:00+00', '2026-07-19 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Hungarian GP', 'Round 13 - Hungaroring', 'Budapest, Ungarn', '2026-07-26 14:00:00+00', '2026-07-26 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Dutch GP', 'Round 14 - Circuit Zandvoort (Sprint)', 'Zandvoort, Niederlande', '2026-08-23 14:00:00+00', '2026-08-23 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Italian GP', 'Round 15 - Autodromo Nazionale Monza', 'Monza, Italien', '2026-09-06 14:00:00+00', '2026-09-06 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Madrid GP', 'Round 16 - Neuer Stadtkurs (Premiere!)', 'Madrid, Spanien', '2026-09-13 14:00:00+00', '2026-09-13 16:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Azerbaijan GP', 'Round 17 - Baku City Circuit', 'Baku, Aserbaidschan', '2026-09-26 12:00:00+00', '2026-09-26 14:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Singapore GP', 'Round 18 - Marina Bay Street Circuit (Sprint, Nachtrennen)', 'Singapur', '2026-10-11 13:00:00+00', '2026-10-11 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - US GP', 'Round 19 - Circuit of the Americas', 'Austin, USA', '2026-10-25 19:00:00+00', '2026-10-25 21:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Mexican GP', 'Round 20 - Autodromo Hermanos Rodriguez', 'Mexico City, Mexiko', '2026-11-01 20:00:00+00', '2026-11-01 22:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Brazilian GP', 'Round 21 - Autodromo Jose Carlos Pace, Interlagos', 'Sao Paulo, Brasilien', '2026-11-08 18:00:00+00', '2026-11-08 20:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Las Vegas GP', 'Round 22 - Las Vegas Strip Circuit (Nachtrennen)', 'Las Vegas, USA', '2026-11-22 06:00:00+00', '2026-11-22 08:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Qatar GP', 'Round 23 - Lusail International Circuit', 'Lusail, Katar', '2026-11-29 15:00:00+00', '2026-11-29 17:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'F1 - Abu Dhabi GP', 'Round 24 - Yas Marina Circuit (Saisonfinale)', 'Abu Dhabi, VAE', '2026-12-06 13:00:00+00', '2026-12-06 15:00:00+00', 'race', 'motorgram', true);

  -- ═══════════════════════════════════════════════════
  -- DTM 2026 (community = 'motorgram', category = 'race')
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, 'DTM - Red Bull Ring', 'Round 1 - Saisonauftakt', 'Spielberg, Oesterreich', '2026-04-26 13:00:00+00', '2026-04-26 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Zandvoort', 'Round 2 - Circuit Zandvoort', 'Zandvoort, Niederlande', '2026-05-24 13:00:00+00', '2026-05-24 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Lausitzring', 'Round 3 - DEKRA Lausitzring', 'Lausitzring, Deutschland', '2026-06-21 13:00:00+00', '2026-06-21 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Norisring', 'Round 4 - Norisring Stadtrennen', 'Nuernberg, Deutschland', '2026-07-05 13:00:00+00', '2026-07-05 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Oschersleben', 'Round 5 - Motorsport Arena Oschersleben', 'Oschersleben, Deutschland', '2026-07-26 13:00:00+00', '2026-07-26 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Nuerburgring', 'Round 6 - Nuerburgring Sprint', 'Nuerburg, Deutschland', '2026-08-16 13:00:00+00', '2026-08-16 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Sachsenring', 'Round 7 - Sachsenring', 'Hohenstein-Ernstthal, Deutschland', '2026-09-13 13:00:00+00', '2026-09-13 15:00:00+00', 'race', 'motorgram', true),
  (system_user_id, 'DTM - Hockenheim', 'Round 8 - Hockenheimring (Saisonfinale)', 'Hockenheim, Deutschland', '2026-10-11 13:00:00+00', '2026-10-11 15:00:00+00', 'race', 'motorgram', true);

  -- ═══════════════════════════════════════════════════
  -- 24H EVENTS (community based on car/bike)
  -- ═══════════════════════════════════════════════════
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (system_user_id, '24h Le Mans 2026', '94. Auflage des legendaeren 24-Stunden-Rennens von Le Mans. Langstrecken-Klassiker!', 'Le Mans, Frankreich', '2026-06-13 14:00:00+00', '2026-06-14 14:00:00+00', 'race', 'motorgram', true),
  (system_user_id, '24h Nuerburgring 2026', '54. ADAC RAVENOL 24h-Rennen - Das Vollgas-Festival in der Gruenen Hoelle!', 'Nuerburg, Deutschland', '2026-05-16 13:00:00+00', '2026-05-17 13:00:00+00', 'race', 'motorgram', true);

  RAISE NOTICE 'Successfully inserted all 2026 motorsport events!';
  RAISE NOTICE 'MotoGP: 22 events (bikergram)';
  RAISE NOTICE 'WSBK: 12 events (bikergram)';
  RAISE NOTICE 'Isle of Man TT: 1 event (bikergram)';
  RAISE NOTICE 'F1: 24 events (motorgram)';
  RAISE NOTICE 'DTM: 8 events (motorgram)';
  RAISE NOTICE '24h Le Mans + 24h Nuerburgring: 2 events (motorgram)';
  RAISE NOTICE 'Total: 69 events';
END;
\$\$;
''');
}
