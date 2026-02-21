-- ============================================================
-- DATABASE CLEAN: Alle User-generierten Daten loeschen
-- Profile bleiben erhalten!
-- Bitte im Supabase SQL-Editor ausfuehren
-- ============================================================
-- Jede Tabelle wird nur geloescht wenn sie existiert.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'story_comments',
    'story_likes',
    'stories',
    'comments',
    'post_likes',
    'post_saves',
    'posts',
    'messages',
    'conversation_participants',
    'conversations',
    'notifications',
    'follows',
    'vehicles',
    'rides',
    'marketplace_listings',
    'event_participants',
    'events',
    'xp_transactions'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = t
    ) THEN
      EXECUTE format('TRUNCATE TABLE public.%I CASCADE', t);
      RAISE NOTICE 'Truncated: %', t;
    ELSE
      RAISE NOTICE 'Skipped (not found): %', t;
    END IF;
  END LOOP;
END $$;

-- Profile-Zaehler zuruecksetzen
UPDATE public.profiles SET xp_total = 0, level = 1;

-- Fertig!
-- Profile, Auth-User und Passwoerter bleiben erhalten.
-- Du kannst dich normal einloggen und hast einen sauberen Start.
