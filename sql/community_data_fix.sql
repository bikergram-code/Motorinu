-- ============================================================
-- FIX: Reset existing community values to NULL
--
-- Problem: The migration set DEFAULT 'bikergram' which assigned
-- 'bikergram' to ALL existing rows. This means Cargram users
-- see nothing because all data is tagged as 'bikergram'.
--
-- Fix: Set existing data to NULL (= visible in ALL communities).
-- New conversations/notifications created going forward will
-- have the correct community set explicitly by the app code.
-- ============================================================

-- 1. Reset all existing conversations to NULL community
UPDATE conversations SET community = NULL;

-- 2. Reset all existing notifications to NULL community
UPDATE notifications SET community = NULL;

-- 3. Change the DEFAULT to NULL (so rows without explicit community show everywhere)
ALTER TABLE conversations ALTER COLUMN community SET DEFAULT NULL;
ALTER TABLE notifications ALTER COLUMN community SET DEFAULT NULL;
