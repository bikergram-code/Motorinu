-- ============================================================
-- FIX: PGRST203 - Remove duplicate/overloaded RPC functions
--
-- Problem: PostgREST can't resolve which function to call
-- because multiple versions with different signatures exist.
-- ============================================================

-- 1. Drop ALL existing versions of get_or_create_conversation
DROP FUNCTION IF EXISTS public.get_or_create_conversation(uuid);
DROP FUNCTION IF EXISTS public.get_or_create_conversation(uuid, text);

-- 2. Recreate with single clean signature
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  other_user_id uuid,
  p_community text DEFAULT NULL
)
RETURNS bigint AS $$
DECLARE
  conv_id bigint;
BEGIN
  -- Check if a conversation already exists between these two users
  IF p_community IS NOT NULL THEN
    -- Look for community-specific conversation
    SELECT c.id INTO conv_id
    FROM public.conversations c
    JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id
    JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id
    WHERE cp1.user_id = auth.uid()
      AND cp2.user_id = other_user_id
      AND c.community = p_community
    LIMIT 1;
  ELSE
    -- Look for any conversation between them
    SELECT c.id INTO conv_id
    FROM public.conversations c
    JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id
    JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id
    WHERE cp1.user_id = auth.uid()
      AND cp2.user_id = other_user_id
    LIMIT 1;
  END IF;

  IF conv_id IS NOT NULL THEN
    RETURN conv_id;
  END IF;

  -- Create new conversation
  INSERT INTO public.conversations (community) VALUES (p_community)
  RETURNING id INTO conv_id;

  -- Add both participants
  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (conv_id, auth.uid()), (conv_id, other_user_id);

  RETURN conv_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Same fix for create_notification
DROP FUNCTION IF EXISTS public.create_notification(uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.create_notification(uuid, text, text, text, jsonb, text);

CREATE OR REPLACE FUNCTION public.create_notification(
  p_target_user_id uuid,
  p_type text,
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}',
  p_community text DEFAULT NULL
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
