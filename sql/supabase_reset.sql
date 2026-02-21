-- ============================================================================
-- BIKERGRAM - KOMPLETTER RESET
-- ============================================================================
-- Schritt 1: Führe dieses Script im Supabase SQL Editor aus
-- Schritt 2: Geh zu Authentication > Providers > Email > "Confirm Email" → AUS
-- ============================================================================

-- Alle Daten löschen (Reihenfolge wegen Foreign Keys)
DELETE FROM public.xp_transactions;
DELETE FROM public.notifications;
DELETE FROM public.messages;
DELETE FROM public.conversation_participants;
DELETE FROM public.conversations;
DELETE FROM public.event_participants;
DELETE FROM public.events;
DELETE FROM public.stories;
DELETE FROM public.blitzer_reports;
DELETE FROM public.marketplace_listings;
DELETE FROM public.rides;
DELETE FROM public.vehicles;
DELETE FROM public.follows;
DELETE FROM public.comments;
DELETE FROM public.post_likes;
DELETE FROM public.posts;
DELETE FROM public.profiles;

-- Alle Auth-User löschen
DELETE FROM auth.users;

-- Sequenzen zurücksetzen (optional)
-- ALTER SEQUENCE public.posts_id_seq RESTART WITH 1;
-- ALTER SEQUENCE public.comments_id_seq RESTART WITH 1;
