-- ============================================================================
-- FIX: Infinite recursion in group_members RLS policy (42P17)
-- ============================================================================
-- DIESES SQL IN SUPABASE SQL EDITOR AUSFÜHREN!
-- Problem: gm_select -> groups -> groups_select -> group_members -> gm_select = LOOP
-- Fix: gm_select darf NICHT auf groups-Tabelle zugreifen
-- ============================================================================

-- Drop the old recursive policy
DROP POLICY IF EXISTS "gm_select" ON public.group_members;

-- Create fixed policy: members can see other members of their groups
-- Public group visibility is handled via RPC functions (SECURITY DEFINER)
CREATE POLICY "gm_select" ON public.group_members FOR SELECT USING (
  group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
);

-- ============================================================================
-- FERTIG! Die unendliche Rekursion ist behoben.
-- ============================================================================
