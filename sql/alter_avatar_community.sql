-- ============================================================================
-- Community-spezifische Profilbilder
-- ============================================================================
-- Ausfuehren in: Supabase Dashboard > SQL Editor > New Query > Paste > Run
-- ============================================================================

-- Zweites Avatar-Feld fuer Cargram-Community.
-- avatar_url bleibt das Bikergram-Profilbild (rueckwaertskompatibel).
-- avatar_url_cargram ist das separate Cargram-Profilbild.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url_cargram text;
