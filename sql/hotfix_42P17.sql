-- ============================================================================
-- HOTFIX: 42P17 Fix + Start/Stop Ride + Delete/Update Group RPCs
-- ============================================================================
-- DIESES SQL IN SUPABASE SQL EDITOR AUSFÜHREN!
-- Fixt: 42P17 Fehler bei allen Gruppen-Operationen
-- ============================================================================

-- ═══════════════════════════════════════════════════
-- 1. get_group_by_id — EXPLICIT columns (fixt 42P17)
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
-- 2. get_group_members
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
-- 3. get_my_groups — EXPLICIT columns (fixt 42P17)
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
-- 4. discover_public_groups — EXPLICIT columns (fixt 42P17)
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
-- 5. start_ride — NEU (bypasses RLS)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.start_ride(p_group_id BIGINT)
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
    RAISE EXCEPTION 'Nur Admins können die Fahrt starten';
  END IF;

  UPDATE public.groups
  SET is_ride_active = TRUE, updated_at = now()
  WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 6. stop_ride — NEU (bypasses RLS)
-- ═══════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════
-- 7. delete_group — NEU (bypasses RLS)
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.delete_group(p_group_id BIGINT)
RETURNS VOID AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND creator_id = v_caller
  ) THEN
    RAISE EXCEPTION 'Nur der Ersteller kann die Gruppe löschen';
  END IF;

  DELETE FROM public.groups WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════
-- 8. update_group — NEU (bypasses RLS)
-- ═══════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════
-- FERTIG! Alle 42P17 Fehler sollten jetzt behoben sein.
-- ═══════════════════════════════════════════════════
