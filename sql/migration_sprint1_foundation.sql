-- ============================================================================
-- SPEC-1 SPRINT 1: Foundation Migration
-- Motorgram Worldwide Feeds + LIVE + Blitzer Compliance
-- ============================================================================
-- Run in: Supabase Dashboard > SQL Editor > New Query > Paste > Run
-- IDEMPOTENT: Safe to run multiple times (IF NOT EXISTS / IF EXISTS checks)
-- ============================================================================

-- ═══════════════════════════════════════════════════
-- 1. POSTS TABLE EXTENSIONS
-- ═══════════════════════════════════════════════════

ALTER TABLE posts ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image'
  CHECK (media_type IN ('image','video','carousel','text'));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS aspect_ratio REAL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS duration_seconds INT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS transcode_status TEXT DEFAULT 'done'
  CHECK (transcode_status IN ('pending','processing','done','failed'));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_count INT DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS save_count INT DEFAULT 0;

-- Backfill media_type for existing posts
UPDATE posts SET media_type = 'video' WHERE video_url IS NOT NULL AND video_url != '' AND media_type IS NULL;
UPDATE posts SET media_type = 'image' WHERE image_url IS NOT NULL AND image_url != '' AND media_type IS NULL;
UPDATE posts SET media_type = 'text' WHERE (image_url IS NULL OR image_url = '') AND (video_url IS NULL OR video_url = '') AND media_type IS NULL;

CREATE INDEX IF NOT EXISTS idx_posts_created_desc ON posts (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_posts_scope_created ON posts (community, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_media_video ON posts (media_type) WHERE media_type = 'video';

-- ═══════════════════════════════════════════════════
-- 2. MEDIA ASSETS (transcoding pipeline)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  original_url TEXT NOT NULL,
  cdn_url TEXT,
  thumbnail_url TEXT,
  media_type TEXT NOT NULL CHECK (media_type IN ('image','video')),
  width INT,
  height INT,
  duration_seconds INT,
  file_size_bytes BIGINT,
  transcode_status TEXT DEFAULT 'pending'
    CHECK (transcode_status IN ('pending','processing','done','failed')),
  transcode_profiles JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "media_assets_select" ON media_assets FOR SELECT USING (true);
CREATE POLICY "media_assets_insert" ON media_assets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "media_assets_update" ON media_assets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "media_assets_delete" ON media_assets FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_media_assets_user ON media_assets (user_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_pending ON media_assets (transcode_status)
  WHERE transcode_status IN ('pending','processing');

-- Carousel support: M2M between posts and media
CREATE TABLE IF NOT EXISTS post_media (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  media_asset_id UUID REFERENCES media_assets(id) ON DELETE CASCADE NOT NULL,
  position INT NOT NULL DEFAULT 0,
  UNIQUE(post_id, media_asset_id)
);
ALTER TABLE post_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY "post_media_select" ON post_media FOR SELECT USING (true);
CREATE POLICY "post_media_insert" ON post_media FOR INSERT WITH CHECK (true);
CREATE POLICY "post_media_delete" ON post_media FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_post_media_post ON post_media (post_id, position);

-- ═══════════════════════════════════════════════════
-- 3. TOPICS + POST_TOPICS + USER_INTERESTS
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS topics (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  label_en TEXT NOT NULL,
  community TEXT DEFAULT 'global'
    CHECK (community IN ('global','bikergram','cargram')),
  icon_url TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true
);
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "topics_select" ON topics FOR SELECT USING (true);

CREATE INDEX IF NOT EXISTS idx_topics_scope ON topics (community, is_active, sort_order);

-- Seed topics
INSERT INTO topics (slug, label_en, sort_order) VALUES
  ('builds',    'Builds & Mods',     1),
  ('trackdays', 'Track Days',        2),
  ('touring',   'Touring & Rides',   3),
  ('garage',    'Garage & Workshop', 4),
  ('racing',    'Racing',            5),
  ('lifestyle', 'Lifestyle',         6),
  ('events',    'Events & Meetups',  7),
  ('reviews',   'Reviews',           8),
  ('diy',       'DIY & How-To',      9),
  ('offroad',   'Off-Road',         10)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS post_topics (
  post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE,
  topic_id INT REFERENCES topics(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, topic_id)
);
ALTER TABLE post_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "post_topics_select" ON post_topics FOR SELECT USING (true);
CREATE POLICY "post_topics_insert" ON post_topics FOR INSERT WITH CHECK (true);
CREATE POLICY "post_topics_delete" ON post_topics FOR DELETE USING (true);

CREATE INDEX IF NOT EXISTS idx_post_topics_topic ON post_topics (topic_id);

CREATE TABLE IF NOT EXISTS user_interests (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  topic_id INT REFERENCES topics(id) ON DELETE CASCADE,
  weight REAL DEFAULT 1.0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, topic_id)
);
ALTER TABLE user_interests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_interests_select" ON user_interests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_interests_insert" ON user_interests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_interests_update" ON user_interests FOR UPDATE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_interests_user ON user_interests (user_id);

-- ═══════════════════════════════════════════════════
-- 4. USER PREFERENCES (community toggle)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  active_community TEXT NOT NULL DEFAULT 'bikergram'
    CHECK (active_community IN ('bikergram','cargram')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "prefs_select" ON user_preferences FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "prefs_insert" ON user_preferences FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "prefs_update" ON user_preferences FOR UPDATE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- 5. FOLLOWS: Community scoping
-- ═══════════════════════════════════════════════════

-- Add community column to follows (existing rows default to bikergram)
ALTER TABLE follows ADD COLUMN IF NOT EXISTS community TEXT NOT NULL DEFAULT 'bikergram'
  CHECK (community IN ('bikergram','cargram'));

-- Drop old unique constraint and create new scoped one
-- (wrapped in DO block for safety)
DO $$
BEGIN
  -- Try to drop old constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'follows_follower_id_following_id_key'
      AND conrelid = 'follows'::regclass
  ) THEN
    ALTER TABLE follows DROP CONSTRAINT follows_follower_id_following_id_key;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_follows_scope
  ON follows (follower_id, following_id, community);

CREATE INDEX IF NOT EXISTS idx_follows_follower_scope
  ON follows (follower_id, community);

-- ═══════════════════════════════════════════════════
-- 6. SAFETY: BLOCKS, MUTES, REPORTS
-- ═══════════════════════════════════════════════════

-- Blocks are GLOBAL (safety)
CREATE TABLE IF NOT EXISTS blocks (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blocks_select" ON blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "blocks_insert" ON blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "blocks_delete" ON blocks FOR DELETE USING (auth.uid() = blocker_id);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks (blocker_id);

-- Mutes are PER-COMMUNITY (content hygiene)
CREATE TABLE IF NOT EXISTS mutes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  muter_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  muted_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  community TEXT NOT NULL DEFAULT 'bikergram'
    CHECK (community IN ('bikergram','cargram')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE mutes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "mutes_select" ON mutes FOR SELECT USING (auth.uid() = muter_id);
CREATE POLICY "mutes_insert" ON mutes FOR INSERT WITH CHECK (auth.uid() = muter_id);
CREATE POLICY "mutes_delete" ON mutes FOR DELETE USING (auth.uid() = muter_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_mutes_scope ON mutes (muter_id, muted_id, community);
CREATE INDEX IF NOT EXISTS idx_mutes_muter ON mutes (muter_id);

-- Reports (unified for all content types)
CREATE TABLE IF NOT EXISTS reports (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reporter_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  target_type TEXT NOT NULL
    CHECK (target_type IN ('post','comment','user','live_session','live_chat_message')),
  target_id TEXT NOT NULL,
  reason TEXT NOT NULL
    CHECK (reason IN ('spam','harassment','nudity','violence','misinformation','other')),
  details TEXT,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','reviewed','actioned','dismissed')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reports_insert" ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "reports_select_own" ON reports FOR SELECT USING (auth.uid() = reporter_id);

CREATE INDEX IF NOT EXISTS idx_reports_target ON reports (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_reports_pending ON reports (status) WHERE status = 'pending';

-- ═══════════════════════════════════════════════════
-- 7. REPOSTS
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS reposts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  original_post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  quote_body TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, original_post_id)
);
ALTER TABLE reposts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reposts_select" ON reposts FOR SELECT USING (true);
CREATE POLICY "reposts_insert" ON reposts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reposts_delete" ON reposts FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_reposts_original ON reposts (original_post_id);

-- ═══════════════════════════════════════════════════
-- 8. LIVE STREAMING TABLES
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS live_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  topic_id INT REFERENCES topics(id),
  status TEXT DEFAULT 'preparing'
    CHECK (status IN ('preparing','live','ended')),
  ivs_channel_arn TEXT,
  ivs_ingest_endpoint TEXT,
  ivs_stream_key TEXT,
  playback_url TEXT,
  thumbnail_url TEXT,
  viewer_count INT DEFAULT 0,
  peak_viewer_count INT DEFAULT 0,
  total_unique_viewers INT DEFAULT 0,
  total_chat_messages INT DEFAULT 0,
  community TEXT NOT NULL DEFAULT 'bikergram'
    CHECK (community IN ('bikergram','cargram')),
  region TEXT,
  language TEXT DEFAULT 'en',
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE live_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_sessions_select" ON live_sessions FOR SELECT USING (true);
CREATE POLICY "live_sessions_insert" ON live_sessions FOR INSERT WITH CHECK (auth.uid() = host_user_id);
CREATE POLICY "live_sessions_update" ON live_sessions FOR UPDATE USING (auth.uid() = host_user_id);

CREATE INDEX IF NOT EXISTS idx_live_sessions_status ON live_sessions (status) WHERE status = 'live';
CREATE INDEX IF NOT EXISTS idx_live_sessions_host ON live_sessions (host_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_scope_status ON live_sessions (community, status, started_at DESC);

CREATE TABLE IF NOT EXISTS live_viewer_sessions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  live_session_id UUID REFERENCES live_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  anon_id TEXT,
  joined_at TIMESTAMPTZ DEFAULT now(),
  left_at TIMESTAMPTZ,
  watch_duration_seconds INT
);
ALTER TABLE live_viewer_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_viewers_select" ON live_viewer_sessions FOR SELECT USING (true);
CREATE POLICY "live_viewers_insert" ON live_viewer_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "live_viewers_update" ON live_viewer_sessions FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_live_viewers_session ON live_viewer_sessions (live_session_id);
CREATE INDEX IF NOT EXISTS idx_live_viewers_user ON live_viewer_sessions (user_id) WHERE user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS live_chat_messages (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  live_session_id UUID REFERENCES live_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  message TEXT NOT NULL,
  deleted_at TIMESTAMPTZ,
  moderation_state TEXT DEFAULT 'visible'
    CHECK (moderation_state IN ('visible','deleted','auto_hidden')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE live_chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_chat_select" ON live_chat_messages FOR SELECT USING (true);
CREATE POLICY "live_chat_insert" ON live_chat_messages FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "live_chat_update" ON live_chat_messages FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_live_chat_session ON live_chat_messages (live_session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_live_chat_user ON live_chat_messages (user_id, live_session_id);

-- Enable Realtime for live chat
ALTER PUBLICATION supabase_realtime ADD TABLE live_chat_messages;

CREATE TABLE IF NOT EXISTS live_moderation_actions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  live_session_id UUID REFERENCES live_sessions(id) ON DELETE CASCADE NOT NULL,
  actor_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  target_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('mute','unmute','block','delete_message')),
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE live_moderation_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "live_mod_select" ON live_moderation_actions FOR SELECT USING (true);
CREATE POLICY "live_mod_insert" ON live_moderation_actions FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_live_mod_session ON live_moderation_actions (live_session_id, target_user_id);

-- ═══════════════════════════════════════════════════
-- 9. FEED EVENTS (analytics + ranking signals)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS feed_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL,
  post_id BIGINT,
  live_session_id UUID,
  event_type TEXT NOT NULL,
  properties JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE feed_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "feed_events_insert" ON feed_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "feed_events_select_own" ON feed_events FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_feed_events_user_time ON feed_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_events_post ON feed_events (post_id) WHERE post_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_feed_events_type_time ON feed_events (event_type, created_at DESC);

-- ═══════════════════════════════════════════════════
-- 10. APP CONFIG (feature flags, banned words, etc.)
-- ═══════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_config_select" ON app_config FOR SELECT USING (true);

INSERT INTO app_config (key, value) VALUES
  ('banned_words', '["spam","scam"]'),
  ('chat_slow_mode_seconds', '2'),
  ('max_reports_auto_flag', '5'),
  ('foryou_weights', '{"freshness":0.20,"engagement":0.25,"media":0.15,"topic":0.20,"completion":0.10,"diversity":0.10}'),
  ('following_weights', '{"freshness":0.70,"engagement":0.20,"media":0.10}')
ON CONFLICT (key) DO NOTHING;

-- ═══════════════════════════════════════════════════
-- 11. BLITZER WORLDWIDE COMPLIANCE
-- ═══════════════════════════════════════════════════

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Country policy table (server-enforced)
CREATE TABLE IF NOT EXISTS blitzer_country_policy (
  country_code CHAR(2) PRIMARY KEY,
  mode TEXT NOT NULL CHECK (mode IN ('off','danger_zone','exact')),
  allow_reporting BOOLEAN NOT NULL DEFAULT false,
  allow_audio_alerts BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now(),
  notes TEXT
);
ALTER TABLE blitzer_country_policy ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blitzer_policy_select" ON blitzer_country_policy FOR SELECT USING (true);

-- Safe defaults
INSERT INTO blitzer_country_policy (country_code, mode, allow_reporting, allow_audio_alerts, notes)
VALUES
  ('CH', 'off', false, false, 'Conservative default - illegal in Switzerland'),
  ('DE', 'exact', true, true, 'Germany - allowed (user responsibility while driving)'),
  ('FR', 'danger_zone', true, false, 'Coarse danger-zone style only'),
  ('AT', 'exact', true, true, 'Austria - allowed'),
  ('IT', 'exact', true, true, 'Italy - allowed'),
  ('ES', 'exact', true, true, 'Spain - allowed'),
  ('NL', 'exact', true, true, 'Netherlands - allowed'),
  ('BE', 'exact', true, true, 'Belgium - allowed'),
  ('PL', 'exact', true, true, 'Poland - allowed'),
  ('US', 'exact', true, true, 'US - generally allowed'),
  ('GB', 'exact', true, true, 'UK - generally allowed')
ON CONFLICT (country_code) DO NOTHING;

-- New PostGIS-based blitzer reports (replaces old lat/lng table for new compliance features)
-- The old blitzer_reports table remains for backward compatibility
-- New table uses UUID PK + PostGIS GEOGRAPHY type
CREATE TABLE IF NOT EXISTS blitzer_reports_v2 (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  community TEXT NOT NULL CHECK (community IN ('bikergram','cargram')),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  report_type TEXT NOT NULL
    CHECK (report_type IN ('speed_camera_fixed','speed_camera_mobile','police','hazard')),
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  heading_deg INT,
  speed_limit_kmh INT,
  road_name TEXT,
  country_code CHAR(2),
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','expired','removed')),
  confirm_count INT NOT NULL DEFAULT 0,
  dismiss_count INT NOT NULL DEFAULT 0,
  confidence REAL NOT NULL DEFAULT 0.5,
  last_activity_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE blitzer_reports_v2 ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blitzer_v2_select" ON blitzer_reports_v2 FOR SELECT USING (status = 'active');
CREATE POLICY "blitzer_v2_insert" ON blitzer_reports_v2 FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_blitzer_v2_scope_status ON blitzer_reports_v2 (community, status, last_activity_at DESC);
CREATE INDEX IF NOT EXISTS idx_blitzer_v2_geo ON blitzer_reports_v2 USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_blitzer_v2_country ON blitzer_reports_v2 (country_code, status);

-- Blitzer votes
CREATE TABLE IF NOT EXISTS blitzer_votes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  report_id UUID REFERENCES blitzer_reports_v2(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  vote TEXT NOT NULL CHECK (vote IN ('confirm','dismiss')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(report_id, user_id)
);
ALTER TABLE blitzer_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blitzer_votes_select" ON blitzer_votes FOR SELECT USING (true);
CREATE POLICY "blitzer_votes_insert" ON blitzer_votes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_blitzer_votes_report ON blitzer_votes (report_id);

-- Confidence update trigger
CREATE OR REPLACE FUNCTION blitzer_apply_vote()
RETURNS TRIGGER AS $$
DECLARE
  c INT;
  d INT;
BEGIN
  UPDATE blitzer_reports_v2
  SET
    confirm_count = confirm_count + CASE WHEN NEW.vote = 'confirm' THEN 1 ELSE 0 END,
    dismiss_count = dismiss_count + CASE WHEN NEW.vote = 'dismiss' THEN 1 ELSE 0 END,
    last_activity_at = now()
  WHERE id = NEW.report_id;

  SELECT confirm_count, dismiss_count INTO c, d
  FROM blitzer_reports_v2 WHERE id = NEW.report_id;

  UPDATE blitzer_reports_v2
  SET confidence = LEAST(0.99, GREATEST(0.01, (c + 1.0) / (c + d + 2.0)))
  WHERE id = NEW.report_id;

  -- Auto-expire if too many dismissals and low confidence
  IF d >= 5 AND (c + 1.0) / (c + d + 2.0) < 0.25 THEN
    UPDATE blitzer_reports_v2
    SET status = 'expired'
    WHERE id = NEW.report_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_blitzer_apply_vote ON blitzer_votes;
CREATE TRIGGER trg_blitzer_apply_vote
AFTER INSERT ON blitzer_votes
FOR EACH ROW EXECUTE FUNCTION blitzer_apply_vote();

-- ═══════════════════════════════════════════════════
-- 12. ADD community TO notifications (if missing)
-- ═══════════════════════════════════════════════════

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS community TEXT DEFAULT 'bikergram'
  CHECK (community IN ('bikergram','cargram'));

-- ═══════════════════════════════════════════════════
-- DONE
-- ═══════════════════════════════════════════════════
-- Next steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Verify tables created: SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
-- 3. Verify indexes: SELECT indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY indexname;
