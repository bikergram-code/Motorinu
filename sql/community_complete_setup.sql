-- ============================================================
-- COMPLETE Community Setup (All-in-One)
--
-- Fuehre dieses Script im Supabase SQL Editor aus.
-- Es erstellt die community-Spalten (falls noch nicht vorhanden),
-- setzt bestehende Daten auf NULL und konfiguriert die RPCs.
-- ============================================================

-- ── 1. Spalten anlegen (falls nicht vorhanden) ───────────────
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS community text DEFAULT NULL;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS community text DEFAULT NULL;

-- ── 2. Bestehende Daten auf NULL setzen ──────────────────────
-- NULL = in ALLEN Communities sichtbar
UPDATE public.conversations SET community = NULL WHERE community IS NOT NULL;
UPDATE public.notifications SET community = NULL WHERE community IS NOT NULL;

-- ── 3. Indexes fuer Performance ──────────────────────────────
CREATE INDEX IF NOT EXISTS idx_conversations_community ON public.conversations(community);
CREATE INDEX IF NOT EXISTS idx_notifications_community ON public.notifications(community);

-- ── 4. create_notification RPC ───────────────────────────────
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
  -- Don't create self-notifications
  IF p_target_user_id = auth.uid() THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data, community)
  VALUES (p_target_user_id, p_type, p_title, p_body, p_data, p_community);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 5. get_or_create_conversation RPC ────────────────────────
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  other_user_id uuid,
  p_community text DEFAULT NULL
)
RETURNS bigint AS $$
DECLARE
  conv_id bigint;
BEGIN
  -- Check if a conversation already exists between these two users
  -- If p_community is set, match exact community
  -- If p_community is NULL, find any conversation between them
  IF p_community IS NOT NULL THEN
    SELECT c.id INTO conv_id
    FROM public.conversations c
    JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id
    JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id
    WHERE cp1.user_id = auth.uid()
      AND cp2.user_id = other_user_id
      AND c.community = p_community
    LIMIT 1;
  ELSE
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

  -- Create new conversation with community
  INSERT INTO public.conversations (community) VALUES (p_community)
  RETURNING id INTO conv_id;

  -- Add both participants
  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (conv_id, auth.uid()), (conv_id, other_user_id);

  RETURN conv_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 6. Realtime Publication ──────────────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
