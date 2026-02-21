-- ============================================================================
-- WhatsApp-Style Messaging — Schema-Erweiterung
-- ============================================================================
-- Ausfuehren in: Supabase Dashboard > SQL Editor > New Query > Paste > Run
-- ============================================================================

-- Neue Spalten fuer erweiterte Nachrichten-Typen
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_duration_ms int;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_lat numeric(10,7);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_lng numeric(10,7);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_name text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reply_to_id bigint REFERENCES public.messages(id);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'text';
