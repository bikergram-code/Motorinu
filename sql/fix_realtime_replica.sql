-- ============================================================
-- FIX: Realtime Replica Identity
--
-- Problem: Supabase Realtime only sends the primary key columns
-- by default. The notification_notifier needs the 'community'
-- column in the realtime payload to filter correctly.
--
-- Fix: Set REPLICA IDENTITY FULL on notifications and messages
-- so that ALL columns are included in realtime payloads.
-- ============================================================

-- Notifications: send ALL columns in realtime events
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Messages: send ALL columns in realtime events
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- Conversations: send ALL columns in realtime events
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
