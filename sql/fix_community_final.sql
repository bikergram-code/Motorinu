-- ============================================================
-- FINAL FIX: Community Separation — Clean Everything
--
-- Run this to verify and fix ALL community issues.
-- Safe to run multiple times.
-- ============================================================

-- 1. Fix any remaining NULL communities
UPDATE public.conversations SET community = 'bikergram' WHERE community IS NULL;
UPDATE public.notifications SET community = 'bikergram' WHERE community IS NULL;

-- 2. Verify: Show counts by community (check in "Results" tab)
SELECT 'conversations' AS tbl, community, count(*) FROM public.conversations GROUP BY community;
SELECT 'notifications' AS tbl, community, count(*) FROM public.notifications GROUP BY community;

-- 3. Ensure NOT NULL constraint
ALTER TABLE public.conversations ALTER COLUMN community SET NOT NULL;
ALTER TABLE public.conversations ALTER COLUMN community SET DEFAULT 'bikergram';
ALTER TABLE public.notifications ALTER COLUMN community SET NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN community SET DEFAULT 'bikergram';

-- 4. Ensure REPLICA IDENTITY FULL (for realtime to include all columns)
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;

-- 5. Drop ALL possible function signatures to avoid overloading
DROP FUNCTION IF EXISTS public.get_or_create_conversation(uuid);
DROP FUNCTION IF EXISTS public.get_or_create_conversation(uuid, text);

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  other_user_id uuid,
  p_community text DEFAULT 'bikergram'
)
RETURNS bigint AS $$
DECLARE
  conv_id bigint;
BEGIN
  -- Always match exact community
  SELECT c.id INTO conv_id
  FROM public.conversations c
  JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id
  JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id
  WHERE cp1.user_id = auth.uid()
    AND cp2.user_id = other_user_id
    AND c.community = p_community
  LIMIT 1;

  IF conv_id IS NOT NULL THEN
    RETURN conv_id;
  END IF;

  INSERT INTO public.conversations (community) VALUES (p_community)
  RETURNING id INTO conv_id;

  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (conv_id, auth.uid()), (conv_id, other_user_id);

  RETURN conv_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Drop ALL possible notification function signatures
DROP FUNCTION IF EXISTS public.create_notification(uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(uuid, text, text, text, jsonb, text);

CREATE OR REPLACE FUNCTION public.create_notification(
  p_target_user_id uuid,
  p_type text,
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}',
  p_community text DEFAULT 'bikergram'
)
RETURNS void AS $$
BEGIN
  IF p_target_user_id = auth.uid() THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data, community)
  VALUES (p_target_user_id, p_type, p_title, p_body, p_data, p_community);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
