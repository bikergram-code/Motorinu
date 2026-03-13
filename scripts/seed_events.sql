-- ═══════════════════════════════════════════════════════════════
-- BIKERGRAM/MOTORGRAM - 2026 Motorsport Events Seed
-- ═══════════════════════════════════════════════════════════════
-- Kopiere dieses SQL in den Supabase SQL Editor:
-- https://supabase.com/dashboard/project/trmwbkpfafigraveneva/sql
--
-- Bikes (bikergram): MotoGP, WSBK, Isle of Man TT
-- Cars (motorgram):  F1, DTM, 24h Le Mans, 24h Nuerburgring
-- ═══════════════════════════════════════════════════════════════

-- STEP 1: Add missing columns
ALTER TABLE events ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'meetup';
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;

-- STEP 2: Storage bucket for event images
INSERT INTO storage.buckets (id, name, public)
VALUES ('events', 'events', true)
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Storage policies
DO $$ BEGIN
  CREATE POLICY "Users can upload event images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'events' AND auth.role() = 'authenticated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Public can read event images" ON storage.objects
  FOR SELECT USING (bucket_id = 'events');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- STEP 4: Insert all motorsport events
DO $$
DECLARE
  sys_uid UUID;
BEGIN
  -- Use first registered user as event creator
  SELECT id INTO sys_uid FROM auth.users ORDER BY created_at ASC LIMIT 1;
  IF sys_uid IS NULL THEN
    RAISE EXCEPTION 'Kein User gefunden!';
  END IF;

  -- ─────────────────────────────────────────────────
  -- MOTOGP 2026 (bikergram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, 'MotoGP - Thai GP', 'Round 1 · Chang International Circuit', 'Buriram, Thailand', '2026-03-01 14:00+00', '2026-03-01 16:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Brazilian GP', 'Round 2 · Autodromo Ayrton Senna', 'Goiania, Brasilien', '2026-03-22 19:00+00', '2026-03-22 21:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Americas GP', 'Round 3 · Circuit of the Americas', 'Austin, USA', '2026-03-29 20:00+00', '2026-03-29 22:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Qatar GP', 'Round 4 · Lusail International Circuit (Nachtrennen)', 'Lusail, Katar', '2026-04-12 18:00+00', '2026-04-12 20:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Spanish GP', 'Round 5 · Circuito de Jerez - Angel Nieto', 'Jerez, Spanien', '2026-04-26 13:00+00', '2026-04-26 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - French GP', 'Round 6 · Circuit Bugatti, Le Mans', 'Le Mans, Frankreich', '2026-05-10 13:00+00', '2026-05-10 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Catalan GP', 'Round 7 · Circuit de Barcelona-Catalunya', 'Barcelona, Spanien', '2026-05-17 13:00+00', '2026-05-17 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Italian GP', 'Round 8 · Autodromo del Mugello', 'Mugello, Italien', '2026-05-31 13:00+00', '2026-05-31 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Hungarian GP', 'Round 9 · Balaton Park Circuit', 'Balatonfured, Ungarn', '2026-06-07 13:00+00', '2026-06-07 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Czech GP', 'Round 10 · Automotodrom Brno', 'Brno, Tschechien', '2026-06-21 13:00+00', '2026-06-21 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Dutch TT', 'Round 11 · TT Circuit Assen', 'Assen, Niederlande', '2026-06-28 13:00+00', '2026-06-28 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - German GP', 'Round 12 · Sachsenring', 'Hohenstein-Ernstthal, Deutschland', '2026-07-12 13:00+00', '2026-07-12 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - British GP', 'Round 13 · Silverstone Circuit', 'Silverstone, England', '2026-08-09 13:00+00', '2026-08-09 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Aragon GP', 'Round 14 · MotorLand Aragon', 'Alcaniz, Spanien', '2026-08-30 13:00+00', '2026-08-30 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - San Marino GP', 'Round 15 · Misano World Circuit Marco Simoncelli', 'Misano Adriatico, Italien', '2026-09-13 13:00+00', '2026-09-13 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Austrian GP', 'Round 16 · Red Bull Ring', 'Spielberg, Oesterreich', '2026-09-20 13:00+00', '2026-09-20 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Japanese GP', 'Round 17 · Mobility Resort Motegi', 'Motegi, Japan', '2026-10-04 06:00+00', '2026-10-04 08:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Indonesian GP', 'Round 18 · Pertamina Mandalika Circuit', 'Lombok, Indonesien', '2026-10-11 08:00+00', '2026-10-11 10:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Australian GP', 'Round 19 · Phillip Island Grand Prix Circuit', 'Phillip Island, Australien', '2026-10-25 04:00+00', '2026-10-25 06:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Malaysian GP', 'Round 20 · Sepang International Circuit', 'Sepang, Malaysia', '2026-11-01 08:00+00', '2026-11-01 10:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Portuguese GP', 'Round 21 · Autodromo Internacional do Algarve', 'Portimao, Portugal', '2026-11-15 14:00+00', '2026-11-15 16:00+00', 'race', 'bikergram', true),
  (sys_uid, 'MotoGP - Valencia GP', 'Round 22 · Circuit Ricardo Tormo (Saisonfinale)', 'Valencia, Spanien', '2026-11-22 14:00+00', '2026-11-22 16:00+00', 'race', 'bikergram', true);

  -- ─────────────────────────────────────────────────
  -- WSBK 2026 (bikergram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, 'WSBK - Phillip Island', 'Round 1 · Phillip Island Grand Prix Circuit', 'Phillip Island, Australien', '2026-02-22 04:00+00', '2026-02-22 06:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Portimao', 'Round 2 · Autodromo Internacional do Algarve', 'Portimao, Portugal', '2026-03-29 14:00+00', '2026-03-29 16:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Assen', 'Round 3 · TT Circuit Assen', 'Assen, Niederlande', '2026-04-19 13:00+00', '2026-04-19 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Balaton Park', 'Round 4 · Balaton Park Circuit', 'Balatonfured, Ungarn', '2026-05-03 13:00+00', '2026-05-03 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Most', 'Round 5 · Autodrom Most', 'Most, Tschechien', '2026-05-17 13:00+00', '2026-05-17 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Aragon', 'Round 6 · MotorLand Aragon', 'Alcaniz, Spanien', '2026-05-31 13:00+00', '2026-05-31 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Misano', 'Round 7 · Misano World Circuit Marco Simoncelli', 'Misano Adriatico, Italien', '2026-06-14 13:00+00', '2026-06-14 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Donington Park', 'Round 8 · Donington Park', 'Castle Donington, England', '2026-07-12 13:00+00', '2026-07-12 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Magny-Cours', 'Round 9 · Circuit de Nevers Magny-Cours', 'Magny-Cours, Frankreich', '2026-09-06 13:00+00', '2026-09-06 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Cremona', 'Round 10 · Cremona Circuit', 'Cremona, Italien', '2026-09-27 13:00+00', '2026-09-27 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Estoril', 'Round 11 · Circuito do Estoril', 'Estoril, Portugal', '2026-10-11 13:00+00', '2026-10-11 15:00+00', 'race', 'bikergram', true),
  (sys_uid, 'WSBK - Jerez', 'Round 12 · Circuito de Jerez (Saisonfinale)', 'Jerez, Spanien', '2026-10-18 13:00+00', '2026-10-18 15:00+00', 'race', 'bikergram', true);

  -- ─────────────────────────────────────────────────
  -- ISLE OF MAN TT 2026 (bikergram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, 'Isle of Man TT 2026', 'Das legendaere Strassenrennen auf der Isle of Man. Practice + Race Week.', 'Isle of Man, England', '2026-05-25 09:00+00', '2026-06-06 18:00+00', 'race', 'bikergram', true);

  -- ─────────────────────────────────────────────────
  -- FORMULA 1 2026 (motorgram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, 'F1 - Australian GP', 'Round 1 · Albert Park Circuit', 'Melbourne, Australien', '2026-03-08 06:00+00', '2026-03-08 08:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Chinese GP', 'Round 2 · Shanghai International Circuit (Sprint)', 'Shanghai, China', '2026-03-15 07:00+00', '2026-03-15 09:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Japanese GP', 'Round 3 · Suzuka Circuit', 'Suzuka, Japan', '2026-03-29 06:00+00', '2026-03-29 08:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Bahrain GP', 'Round 4 · Bahrain International Circuit', 'Sakhir, Bahrain', '2026-04-12 15:00+00', '2026-04-12 17:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Saudi Arabian GP', 'Round 5 · Jeddah Corniche Circuit', 'Jeddah, Saudi-Arabien', '2026-04-19 17:00+00', '2026-04-19 19:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Miami GP', 'Round 6 · Miami International Autodrome (Sprint)', 'Miami, USA', '2026-05-03 20:00+00', '2026-05-03 22:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Canadian GP', 'Round 7 · Circuit Gilles Villeneuve (Sprint)', 'Montreal, Kanada', '2026-05-24 18:00+00', '2026-05-24 20:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Monaco GP', 'Round 8 · Circuit de Monaco', 'Monte Carlo, Monaco', '2026-06-07 13:00+00', '2026-06-07 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Spanish GP', 'Round 9 · Circuit de Barcelona-Catalunya', 'Barcelona, Spanien', '2026-06-14 13:00+00', '2026-06-14 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Austrian GP', 'Round 10 · Red Bull Ring', 'Spielberg, Oesterreich', '2026-06-28 13:00+00', '2026-06-28 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - British GP', 'Round 11 · Silverstone Circuit (Sprint)', 'Silverstone, England', '2026-07-05 14:00+00', '2026-07-05 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Belgian GP', 'Round 12 · Circuit de Spa-Francorchamps', 'Spa, Belgien', '2026-07-19 14:00+00', '2026-07-19 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Hungarian GP', 'Round 13 · Hungaroring', 'Budapest, Ungarn', '2026-07-26 14:00+00', '2026-07-26 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Dutch GP', 'Round 14 · Circuit Zandvoort (Sprint)', 'Zandvoort, Niederlande', '2026-08-23 14:00+00', '2026-08-23 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Italian GP', 'Round 15 · Autodromo Nazionale Monza', 'Monza, Italien', '2026-09-06 14:00+00', '2026-09-06 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Madrid GP', 'Round 16 · Neuer Stadtkurs (Premiere!)', 'Madrid, Spanien', '2026-09-13 14:00+00', '2026-09-13 16:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Azerbaijan GP', 'Round 17 · Baku City Circuit', 'Baku, Aserbaidschan', '2026-09-26 12:00+00', '2026-09-26 14:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Singapore GP', 'Round 18 · Marina Bay Street Circuit (Sprint, Nachtrennen)', 'Singapur', '2026-10-11 13:00+00', '2026-10-11 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - US GP', 'Round 19 · Circuit of the Americas', 'Austin, USA', '2026-10-25 19:00+00', '2026-10-25 21:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Mexican GP', 'Round 20 · Autodromo Hermanos Rodriguez', 'Mexico City, Mexiko', '2026-11-01 20:00+00', '2026-11-01 22:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Brazilian GP', 'Round 21 · Autodromo Jose Carlos Pace, Interlagos', 'Sao Paulo, Brasilien', '2026-11-08 18:00+00', '2026-11-08 20:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Las Vegas GP', 'Round 22 · Las Vegas Strip Circuit (Nachtrennen)', 'Las Vegas, USA', '2026-11-22 06:00+00', '2026-11-22 08:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Qatar GP', 'Round 23 · Lusail International Circuit', 'Lusail, Katar', '2026-11-29 15:00+00', '2026-11-29 17:00+00', 'race', 'motorgram', true),
  (sys_uid, 'F1 - Abu Dhabi GP', 'Round 24 · Yas Marina Circuit (Saisonfinale)', 'Abu Dhabi, VAE', '2026-12-06 13:00+00', '2026-12-06 15:00+00', 'race', 'motorgram', true);

  -- ─────────────────────────────────────────────────
  -- DTM 2026 (motorgram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, 'DTM - Red Bull Ring', 'Round 1 · Saisonauftakt', 'Spielberg, Oesterreich', '2026-04-26 13:00+00', '2026-04-26 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Zandvoort', 'Round 2 · Circuit Zandvoort', 'Zandvoort, Niederlande', '2026-05-24 13:00+00', '2026-05-24 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Lausitzring', 'Round 3 · DEKRA Lausitzring', 'Lausitzring, Deutschland', '2026-06-21 13:00+00', '2026-06-21 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Norisring', 'Round 4 · Norisring Stadtrennen', 'Nuernberg, Deutschland', '2026-07-05 13:00+00', '2026-07-05 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Oschersleben', 'Round 5 · Motorsport Arena Oschersleben', 'Oschersleben, Deutschland', '2026-07-26 13:00+00', '2026-07-26 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Nuerburgring', 'Round 6 · Nuerburgring Sprint', 'Nuerburg, Deutschland', '2026-08-16 13:00+00', '2026-08-16 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Sachsenring', 'Round 7 · Sachsenring', 'Hohenstein-Ernstthal, Deutschland', '2026-09-13 13:00+00', '2026-09-13 15:00+00', 'race', 'motorgram', true),
  (sys_uid, 'DTM - Hockenheim', 'Round 8 · Hockenheimring (Saisonfinale)', 'Hockenheim, Deutschland', '2026-10-11 13:00+00', '2026-10-11 15:00+00', 'race', 'motorgram', true);

  -- ─────────────────────────────────────────────────
  -- 24H LANGSTRECKENRENNEN (motorgram)
  -- ─────────────────────────────────────────────────
  INSERT INTO events (user_id, title, description, location_text, starts_at, ends_at, category, community, is_featured) VALUES
  (sys_uid, '24h Le Mans 2026', '94. Auflage des legendaeren 24-Stunden-Rennens von Le Mans', 'Le Mans, Frankreich', '2026-06-13 14:00+00', '2026-06-14 14:00+00', 'race', 'motorgram', true),
  (sys_uid, '24h Nuerburgring 2026', '54. ADAC RAVENOL 24h-Rennen in der Gruenen Hoelle', 'Nuerburg, Deutschland', '2026-05-16 13:00+00', '2026-05-17 13:00+00', 'race', 'motorgram', true);

  RAISE NOTICE '=== DONE: 69 Motorsport Events eingefuegt! ===';
  RAISE NOTICE 'Bikes (bikergram): 22 MotoGP + 12 WSBK + 1 IoM TT = 35';
  RAISE NOTICE 'Cars (motorgram):  24 F1 + 8 DTM + 2 24h = 34';
END;
$$;
