-- Sprint 5: Moderation tables — reports + blocks/mutes cleanup
-- Run via Supabase Dashboard → SQL Editor

-- ═══════════════════════════════════════════════════
-- REPORTS TABLE
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS reports (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('post','user','comment','live','message')),
  target_id TEXT NOT NULL,  -- can be post_id, user_id, comment_id etc.
  reason TEXT NOT NULL CHECK (reason IN (
    'spam','harassment','hate_speech','violence',
    'nudity','misinformation','copyright','other'
  )),
  details TEXT,  -- optional free text from reporter
  community TEXT DEFAULT 'bikergram',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','resolved','dismissed')),
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_target ON reports (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports (reporter_id);

-- Prevent duplicate reports from same user on same target
CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_unique
  ON reports (reporter_id, target_type, target_id);

-- ═══════════════════════════════════════════════════
-- BLOCKS TABLE (ensure exists with unique constraint)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS blocks (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_blocks_pair
  ON blocks (blocker_id, blocked_id);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker
  ON blocks (blocker_id);

-- ═══════════════════════════════════════════════════
-- MUTES TABLE (per-community, ensure exists)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS mutes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  muter_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  muted_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  community TEXT NOT NULL DEFAULT 'bikergram'
    CHECK (community IN ('bikergram','cargram')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_mutes_scope
  ON mutes (muter_id, muted_id, community);

CREATE INDEX IF NOT EXISTS idx_mutes_muter
  ON mutes (muter_id, community);

-- ═══════════════════════════════════════════════════
-- RLS POLICIES
-- ═══════════════════════════════════════════════════

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE mutes ENABLE ROW LEVEL SECURITY;

-- Reports: user can insert (create report) and read own reports
CREATE POLICY "Users can create reports"
  ON reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view own reports"
  ON reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- Blocks: user can manage their own blocks
CREATE POLICY "Users can manage own blocks"
  ON blocks FOR ALL
  USING (auth.uid() = blocker_id);

-- Mutes: user can manage their own mutes
CREATE POLICY "Users can manage own mutes"
  ON mutes FOR ALL
  USING (auth.uid() = muter_id);
