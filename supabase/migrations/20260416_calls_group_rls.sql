-- ============================================================================
-- CALLS TABLE — RLS + REALTIME FIX FOR GROUP CALLS
-- Datum: 2026-04-16
--
-- Problem: Gruppen-Anrufe klingelten nicht auf den Geräten anderer
-- Gruppenmitglieder. Ursache: Supabase Realtime respektiert RLS.
-- Wenn die SELECT-Policy auf `calls` keine Gruppenmitglieder einschließt,
-- liefert Realtime die INSERT-Events nicht an sie aus — der Client sieht
-- den neuen Call gar nicht erst.
--
-- Fix:
--   1. SELECT-Policy erweitern: caller OR callee OR Mitglied der Gruppe
--   2. INSERT-Policy: nur als caller selbst anlegen
--   3. UPDATE-Policy: caller, callee oder Gruppenmitglied darf updaten
--      (z.B. für accept/decline/end)
--   4. REPLICA IDENTITY FULL → vollständige Payload in Realtime-UPDATEs
--   5. Tabelle zur supabase_realtime Publication hinzufügen
--
-- IDEMPOTENT: Safe to re-run.
-- ============================================================================

-- ─── 1. SICHERSTELLEN DASS TABELLE EXISTIERT ────────────────────────────────
-- (Falls calls manuell im Dashboard erstellt wurde — nichts überschreiben,
-- nur die erwarteten Spalten garantieren.)

CREATE TABLE IF NOT EXISTS public.calls (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  caller_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  callee_id     UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id BIGINT,
  group_id      BIGINT REFERENCES public.groups(id) ON DELETE CASCADE,
  call_type     TEXT NOT NULL DEFAULT 'voice'
                CHECK (call_type IN ('voice', 'video')),
  status        TEXT NOT NULL DEFAULT 'ringing'
                CHECK (status IN ('ringing', 'active', 'accepted',
                                  'declined', 'ended', 'missed', 'busy')),
  livekit_room  TEXT,
  started_at    TIMESTAMPTZ,
  ended_at      TIMESTAMPTZ,
  duration_seconds INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hilfs-Indexe
CREATE INDEX IF NOT EXISTS calls_caller_idx   ON public.calls (caller_id);
CREATE INDEX IF NOT EXISTS calls_callee_idx   ON public.calls (callee_id);
CREATE INDEX IF NOT EXISTS calls_group_idx    ON public.calls (group_id);
CREATE INDEX IF NOT EXISTS calls_status_idx   ON public.calls (status);
CREATE INDEX IF NOT EXISTS calls_created_idx  ON public.calls (created_at DESC);

-- ─── 2. RLS AKTIVIEREN ──────────────────────────────────────────────────────
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

-- ─── 3. ALTE POLICIES LÖSCHEN (falls vorhanden) ────────────────────────────
-- So können wir die Policies neu und konsistent anlegen, ohne
-- "policy already exists"-Fehler zu bekommen.
DROP POLICY IF EXISTS "calls_select_participant"    ON public.calls;
DROP POLICY IF EXISTS "calls_select_own"            ON public.calls;
DROP POLICY IF EXISTS "calls_select_caller_callee"  ON public.calls;
DROP POLICY IF EXISTS "calls_insert_own"            ON public.calls;
DROP POLICY IF EXISTS "calls_insert_caller"         ON public.calls;
DROP POLICY IF EXISTS "calls_update_participant"    ON public.calls;
DROP POLICY IF EXISTS "calls_update_own"            ON public.calls;

-- ─── 4. NEUE POLICIES ───────────────────────────────────────────────────────

-- SELECT: caller, callee ODER Mitglied der Anruf-Gruppe
-- ↳ Nur so delivered Supabase Realtime die INSERT-Events an Gruppenmitglieder!
CREATE POLICY "calls_select_participant" ON public.calls
  FOR SELECT USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
    OR (
      group_id IS NOT NULL
      AND group_id IN (
        SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
      )
    )
  );

-- INSERT: nur als caller selbst erzeugen
CREATE POLICY "calls_insert_caller" ON public.calls
  FOR INSERT WITH CHECK (caller_id = auth.uid());

-- UPDATE: caller, callee oder Gruppenmitglied (für accept/decline/end)
CREATE POLICY "calls_update_participant" ON public.calls
  FOR UPDATE USING (
    caller_id = auth.uid()
    OR callee_id = auth.uid()
    OR (
      group_id IS NOT NULL
      AND group_id IN (
        SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
      )
    )
  );

-- ─── 5. REPLICA IDENTITY FULL ──────────────────────────────────────────────
-- Damit UPDATE-Events (z.B. Statuswechsel auf 'active' / 'ended') die
-- kompletten Spalten im Realtime-Payload enthalten, nicht nur die PK.
ALTER TABLE public.calls REPLICA IDENTITY FULL;

-- ─── 6. REALTIME PUBLICATION ───────────────────────────────────────────────
-- Tabelle zur supabase_realtime Publication hinzufügen — nur wenn sie
-- noch nicht drin ist (sonst Fehler).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'calls'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.calls';
  END IF;
END $$;

-- ============================================================================
-- VERIFIZIERUNG (nach dem Ausführen manuell testen):
--
--   -- Als anderer User (z.B. Gruppenmitglied) loggen und prüfen:
--   SELECT id, caller_id, group_id, status FROM public.calls
--   WHERE group_id = <deine-gruppen-id>
--   ORDER BY created_at DESC LIMIT 5;
--
--   -- Muss Zeilen zurückgeben wenn der User in der Gruppe ist.
--
--   -- Check Publication:
--   SELECT tablename FROM pg_publication_tables
--   WHERE pubname = 'supabase_realtime' AND tablename = 'calls';
-- ============================================================================
