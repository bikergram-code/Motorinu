-- ============================================================================
-- HOTFIX: RLS-Rekursion beim Gruppenanruf (42P17)
-- Datum: 2026-04-16
--
-- Problem: Die vorherige Migration "20260416_calls_group_rls.sql" hat
-- eine SELECT-Policy auf `calls` angelegt, die auf `group_members`
-- verweist:
--     group_id IN (SELECT group_id FROM group_members WHERE user_id = auth.uid())
--
-- `group_members` hat bereits eine eigene RLS-Policy `gm_select`, die
-- wiederum auf `group_members` selbst verweist → endlose Rekursion.
-- PostgreSQL wirft: 42P17 "infinite recursion detected in policy".
--
-- Lösung (wie der Codebase bereits bei `get_group_by_id` etc. nutzt):
-- SECURITY DEFINER Helper-Funktion `is_group_member(...)` schreiben,
-- die RLS komplett umgeht, und die Calls-Policy auf diese Funktion
-- umstellen.
--
-- IDEMPOTENT: Safe to re-run.
-- ============================================================================

-- ─── 1. SECURITY DEFINER Helper ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_group_member(
  p_group_id BIGINT,
  p_user_id  UUID
) RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = p_user_id
  );
$$;

-- Nur authenticated Nutzer dürfen die Funktion ausführen
REVOKE ALL ON FUNCTION public.is_group_member(BIGINT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_group_member(BIGINT, UUID) TO authenticated;

-- ─── 2. ALTE Calls-Policies droppen ────────────────────────────────────────
DROP POLICY IF EXISTS "calls_select_participant"    ON public.calls;
DROP POLICY IF EXISTS "calls_select_own"            ON public.calls;
DROP POLICY IF EXISTS "calls_select_caller_callee"  ON public.calls;
DROP POLICY IF EXISTS "calls_insert_caller"         ON public.calls;
DROP POLICY IF EXISTS "calls_insert_own"            ON public.calls;
DROP POLICY IF EXISTS "calls_update_participant"    ON public.calls;
DROP POLICY IF EXISTS "calls_update_own"            ON public.calls;

-- ─── 3. NEUE Policies mit SECURITY-DEFINER-Helper (keine Rekursion) ───────

-- SELECT: caller, callee ODER Gruppenmitglied
CREATE POLICY "calls_select_participant" ON public.calls
  FOR SELECT USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
    OR (
      group_id IS NOT NULL
      AND public.is_group_member(group_id, auth.uid())
    )
  );

-- INSERT: nur als caller selbst anlegen
CREATE POLICY "calls_insert_caller" ON public.calls
  FOR INSERT WITH CHECK (caller_id = auth.uid());

-- UPDATE: caller, callee oder Gruppenmitglied
CREATE POLICY "calls_update_participant" ON public.calls
  FOR UPDATE USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
    OR (
      group_id IS NOT NULL
      AND public.is_group_member(group_id, auth.uid())
    )
  );

-- ============================================================================
-- VERIFIZIERUNG:
--
--   -- Policies prüfen (sollte 3 Zeilen zeigen):
--   SELECT policyname, cmd FROM pg_policies WHERE tablename = 'calls';
--
--   -- Helper testen (als authenticated user mit bekannter group-id):
--   SELECT public.is_group_member(1, auth.uid());
-- ============================================================================
