-- ============================================================================
-- GROUPS MIGRATION - Fahrgruppen, Chat-Gruppen, Community-Clubs
-- ============================================================================
-- IDEMPOTENT: Safe to run multiple times

-- ═══════════════════════════════════════════════════
-- 1. CREATE TABLES FIRST (no policies yet)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.groups (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  group_type TEXT NOT NULL DEFAULT 'chat'
    CHECK (group_type IN ('ride', 'chat', 'club')),
  community TEXT DEFAULT 'bikergram'
    CHECK (community IN ('bikergram', 'cargram')),
  is_ride_active BOOLEAN DEFAULT FALSE,
  ride_color TEXT DEFAULT '#4CAF50',
  is_public BOOLEAN DEFAULT TRUE,
  member_count INT DEFAULT 1,
  max_members INT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_members (
  group_id BIGINT REFERENCES public.groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- ═══════════════════════════════════════════════════
-- 2. RLS + POLICIES (both tables exist now)
-- ═══════════════════════════════════════════════════

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  -- GROUPS policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'groups_select' AND tablename = 'groups') THEN
    CREATE POLICY "groups_select" ON public.groups FOR SELECT USING (
      is_public = TRUE
      OR id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'groups_insert' AND tablename = 'groups') THEN
    CREATE POLICY "groups_insert" ON public.groups FOR INSERT WITH CHECK (auth.uid() = creator_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'groups_update' AND tablename = 'groups') THEN
    CREATE POLICY "groups_update" ON public.groups FOR UPDATE USING (
      creator_id = auth.uid()
      OR id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid() AND role = 'admin')
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'groups_delete' AND tablename = 'groups') THEN
    CREATE POLICY "groups_delete" ON public.groups FOR DELETE USING (creator_id = auth.uid());
  END IF;

  -- GROUP_MEMBERS policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'gm_select' AND tablename = 'group_members') THEN
    CREATE POLICY "gm_select" ON public.group_members FOR SELECT USING (
      group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
      OR group_id IN (SELECT id FROM public.groups WHERE is_public = TRUE)
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'gm_insert' AND tablename = 'group_members') THEN
    CREATE POLICY "gm_insert" ON public.group_members FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'gm_delete' AND tablename = 'group_members') THEN
    CREATE POLICY "gm_delete" ON public.group_members FOR DELETE USING (
      auth.uid() = user_id
      OR group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid() AND role = 'admin')
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'gm_update' AND tablename = 'group_members') THEN
    CREATE POLICY "gm_update" ON public.group_members FOR UPDATE USING (
      group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- ═══════════════════════════════════════════════════
-- 3. INDEXES
-- ═══════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_groups_community ON public.groups(community);
CREATE INDEX IF NOT EXISTS idx_groups_type ON public.groups(group_type);
CREATE INDEX IF NOT EXISTS idx_groups_creator ON public.groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_gm_user ON public.group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_gm_group ON public.group_members(group_id);

-- ═══════════════════════════════════════════════════
-- 4. LINK GROUPS TO CONVERSATIONS
-- ═══════════════════════════════════════════════════

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS group_id BIGINT REFERENCES public.groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_group ON public.conversations(group_id)
  WHERE group_id IS NOT NULL;

-- ═══════════════════════════════════════════════════
-- 5. RPC: Create group with conversation + auto-join creator
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.create_group(
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_group_type TEXT DEFAULT 'chat',
  p_community TEXT DEFAULT 'bikergram',
  p_is_public BOOLEAN DEFAULT TRUE,
  p_ride_color TEXT DEFAULT '#4CAF50',
  p_max_members INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
  v_group_id BIGINT;
  v_conv_id BIGINT;
  v_user_id UUID := auth.uid();
BEGIN
  INSERT INTO public.groups (creator_id, name, description, group_type, community, is_public, ride_color, max_members)
  VALUES (v_user_id, p_name, p_description, p_group_type, p_community, p_is_public, p_ride_color, p_max_members)
  RETURNING id INTO v_group_id;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_group_id, v_user_id, 'admin');

  INSERT INTO public.conversations (group_id, community)
  VALUES (v_group_id, p_community)
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_participants (conversation_id, user_id)
  VALUES (v_conv_id, v_user_id);

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 6. RPC: Join group
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.join_group(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_conv_id BIGINT;
  v_current_count INT;
  v_max INT;
BEGIN
  SELECT member_count, max_members INTO v_current_count, v_max
  FROM public.groups WHERE id = p_group_id;

  IF v_max IS NOT NULL AND v_current_count >= v_max THEN
    RAISE EXCEPTION 'Gruppe ist voll';
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (p_group_id, v_user_id, 'member')
  ON CONFLICT DO NOTHING;

  UPDATE public.groups SET member_count = member_count + 1
  WHERE id = p_group_id;

  SELECT id INTO v_conv_id FROM public.conversations
  WHERE group_id = p_group_id LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv_id, v_user_id)
    ON CONFLICT DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 7. RPC: Leave group
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.leave_group(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_conv_id BIGINT;
BEGIN
  DELETE FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  UPDATE public.groups SET member_count = GREATEST(member_count - 1, 0)
  WHERE id = p_group_id;

  SELECT id INTO v_conv_id FROM public.conversations
  WHERE group_id = p_group_id LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants
    WHERE conversation_id = v_conv_id AND user_id = v_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 8. RPC: Add members to group (admin action)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.add_members_to_group(
  p_group_id BIGINT,
  p_user_ids UUID[]
)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_conv_id BIGINT;
  v_uid UUID;
BEGIN
  -- Verify caller is admin of the group
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_caller AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Nur Admins können Mitglieder hinzufügen';
  END IF;

  -- Get conversation for this group
  SELECT id INTO v_conv_id FROM public.conversations
  WHERE group_id = p_group_id LIMIT 1;

  FOREACH v_uid IN ARRAY p_user_ids LOOP
    -- Add to group_members
    INSERT INTO public.group_members (group_id, user_id, role)
    VALUES (p_group_id, v_uid, 'member')
    ON CONFLICT DO NOTHING;

    -- Add to conversation
    IF v_conv_id IS NOT NULL THEN
      INSERT INTO public.conversation_participants (conversation_id, user_id)
      VALUES (v_conv_id, v_uid)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  -- Update member count
  UPDATE public.groups SET member_count = (
    SELECT COUNT(*) FROM public.group_members WHERE group_id = p_group_id
  ) WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 9. Realtime support
-- ═══════════════════════════════════════════════════

ALTER TABLE public.groups REPLICA IDENTITY FULL;
ALTER TABLE public.group_members REPLICA IDENTITY FULL;

-- ═══════════════════════════════════════════════════
-- 10. RPC: Get my groups (bypasses RLS for reliability)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_my_groups(p_community TEXT DEFAULT 'bikergram')
RETURNS SETOF JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT row_to_json(t) FROM (
    SELECT
      g.*,
      gm.role AS user_role
    FROM public.groups g
    INNER JOIN public.group_members gm ON gm.group_id = g.id
    WHERE gm.user_id = v_user_id
      AND g.community = p_community
    ORDER BY g.updated_at DESC
  ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 11. RPC: Discover public groups (bypasses RLS)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.discover_public_groups(
  p_community TEXT DEFAULT 'bikergram',
  p_group_type TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50
)
RETURNS SETOF JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT row_to_json(t) FROM (
    SELECT g.*
    FROM public.groups g
    WHERE g.is_public = TRUE
      AND g.community = p_community
      AND (p_group_type IS NULL OR g.group_type = p_group_type)
      AND g.id NOT IN (
        SELECT gm.group_id FROM public.group_members gm WHERE gm.user_id = v_user_id
      )
    ORDER BY g.member_count DESC
    LIMIT p_limit
  ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 12. RPC: Kick member (admin action)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.kick_member(
  p_group_id BIGINT,
  p_user_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_conv_id BIGINT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_caller AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Nur Admins können Mitglieder entfernen';
  END IF;

  IF v_caller = p_user_id THEN
    RAISE EXCEPTION 'Du kannst dich nicht selbst entfernen';
  END IF;

  DELETE FROM public.group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;

  SELECT id INTO v_conv_id FROM public.conversations
  WHERE group_id = p_group_id LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    DELETE FROM public.conversation_participants
    WHERE conversation_id = v_conv_id AND user_id = p_user_id;
  END IF;

  UPDATE public.groups SET member_count = (
    SELECT COUNT(*) FROM public.group_members WHERE group_id = p_group_id
  ) WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 13. ADD RIDE NAVIGATION COLUMNS
-- ═══════════════════════════════════════════════════
-- Destination that all group members can navigate to during a ride.

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS destination_lat NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS destination_lng NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS destination_name TEXT;

-- ═══════════════════════════════════════════════════
-- 14. RPC: Get group by ID (bypasses RLS for reliable loading)
-- EXPLICIT columns to avoid 42P17 ambiguity with JOINs
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_group_by_id(p_group_id BIGINT)
RETURNS JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result JSON;
BEGIN
  SELECT row_to_json(t) INTO v_result FROM (
    SELECT
      g.id,
      g.creator_id,
      g.name,
      g.description,
      g.avatar_url,
      g.group_type,
      g.community,
      g.is_ride_active,
      g.ride_color,
      g.is_public,
      g.member_count,
      g.max_members,
      g.destination_lat,
      g.destination_lng,
      g.destination_name,
      g.created_at,
      g.updated_at,
      gm.role AS user_role,
      c.id AS conversation_id,
      p.username AS creator_username,
      p.display_name AS creator_display_name,
      p.avatar_url AS creator_avatar_url
    FROM public.groups g
    LEFT JOIN public.group_members gm ON gm.group_id = g.id AND gm.user_id = v_user_id
    LEFT JOIN public.conversations c ON c.group_id = g.id
    LEFT JOIN public.profiles p ON p.id = g.creator_id
    WHERE g.id = p_group_id
  ) t;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 15. RPC: Get group members (bypasses RLS for reliable loading)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_group_members(p_group_id BIGINT)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_agg(row_to_json(t)) INTO v_result FROM (
    SELECT
      gm.group_id,
      gm.user_id,
      gm.role,
      gm.joined_at,
      p.username,
      p.display_name,
      p.avatar_url
    FROM public.group_members gm
    LEFT JOIN public.profiles p ON p.id = gm.user_id
    WHERE gm.group_id = p_group_id
    ORDER BY gm.role ASC, gm.joined_at ASC
  ) t;
  RETURN COALESCE(v_result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 16. RPC: Get my groups — EXPLICIT columns (fixes 42P17)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_my_groups(p_community TEXT DEFAULT 'bikergram')
RETURNS SETOF JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT row_to_json(t) FROM (
    SELECT
      g.id,
      g.creator_id,
      g.name,
      g.description,
      g.avatar_url,
      g.group_type,
      g.community,
      g.is_ride_active,
      g.ride_color,
      g.is_public,
      g.member_count,
      g.max_members,
      g.destination_lat,
      g.destination_lng,
      g.destination_name,
      g.created_at,
      g.updated_at,
      gm.role AS user_role
    FROM public.groups g
    INNER JOIN public.group_members gm ON gm.group_id = g.id
    WHERE gm.user_id = v_user_id
      AND g.community = p_community
    ORDER BY g.updated_at DESC
  ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 17. RPC: Discover public groups — EXPLICIT columns (fixes 42P17)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.discover_public_groups(
  p_community TEXT DEFAULT 'bikergram',
  p_group_type TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50
)
RETURNS SETOF JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT row_to_json(t) FROM (
    SELECT
      g.id,
      g.creator_id,
      g.name,
      g.description,
      g.avatar_url,
      g.group_type,
      g.community,
      g.is_ride_active,
      g.ride_color,
      g.is_public,
      g.member_count,
      g.max_members,
      g.destination_lat,
      g.destination_lng,
      g.destination_name,
      g.created_at,
      g.updated_at
    FROM public.groups g
    WHERE g.is_public = TRUE
      AND g.community = p_community
      AND (p_group_type IS NULL OR g.group_type = p_group_type)
      AND g.id NOT IN (
        SELECT gm.group_id FROM public.group_members gm WHERE gm.user_id = v_user_id
      )
    ORDER BY g.member_count DESC
    LIMIT p_limit
  ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 18. RPC: Start/Stop ride + Delete group (bypasses RLS)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.start_ride(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  -- Verify caller is admin or creator
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND creator_id = v_caller
  ) AND NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_caller AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Nur Admins können die Fahrt starten';
  END IF;

  UPDATE public.groups
  SET is_ride_active = TRUE, updated_at = now()
  WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.stop_ride(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND creator_id = v_caller
  ) AND NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_caller AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Nur Admins können die Fahrt stoppen';
  END IF;

  UPDATE public.groups
  SET is_ride_active = FALSE,
      destination_lat = NULL,
      destination_lng = NULL,
      destination_name = NULL,
      updated_at = now()
  WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.delete_group(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  -- Only creator can delete
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND creator_id = v_caller
  ) THEN
    RAISE EXCEPTION 'Nur der Ersteller kann die Gruppe löschen';
  END IF;

  DELETE FROM public.groups WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.update_group(
  p_group_id BIGINT,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL,
  p_is_public BOOLEAN DEFAULT NULL,
  p_ride_color TEXT DEFAULT NULL,
  p_max_members INT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  -- Verify caller is admin or creator
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND creator_id = v_caller
  ) AND NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_caller AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Nur Admins können die Gruppe bearbeiten';
  END IF;

  UPDATE public.groups SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    is_public = COALESCE(p_is_public, is_public),
    ride_color = COALESCE(p_ride_color, ride_color),
    max_members = COALESCE(p_max_members, max_members),
    updated_at = now()
  WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
