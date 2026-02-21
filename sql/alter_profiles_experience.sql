-- ============================================================
-- Bikergram: Fahrerfahrung + Alter + PLZ Erweiterung
-- Bitte im Supabase Dashboard → SQL Editor ausfuehren
-- ============================================================

-- 1. Neue Spalten zur profiles Tabelle hinzufuegen
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_year int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS moto_start_age int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS car_start_age int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_track_experience boolean DEFAULT false;
