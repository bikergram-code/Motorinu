-- ============================================================
-- DIAGNOSE: What's in the database?
-- Run this and check the Results tab for each query
-- ============================================================

-- 1. Check conversations: what communities exist?
SELECT id, community, created_at FROM public.conversations ORDER BY created_at DESC LIMIT 20;

-- 2. Check notifications: what communities exist?
SELECT id, type, title, community, created_at FROM public.notifications ORDER BY created_at DESC LIMIT 20;

-- 3. Are there ANY null communities left?
SELECT 'conversations_null' AS check, count(*) FROM public.conversations WHERE community IS NULL;
SELECT 'notifications_null' AS check, count(*) FROM public.notifications WHERE community IS NULL;

-- 4. Check the column definition — is NOT NULL enforced?
SELECT column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'conversations' AND column_name = 'community';

SELECT column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'notifications' AND column_name = 'community';

-- 5. List ALL function signatures for our RPCs
SELECT p.proname, pg_get_function_arguments(p.oid) as args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN ('get_or_create_conversation', 'create_notification');
