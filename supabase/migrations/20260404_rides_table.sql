-- Rides table for tracking driven kilometers and XP
CREATE TABLE IF NOT EXISTS rides (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  distance_km double precision NOT NULL DEFAULT 0,
  duration_seconds integer NOT NULL DEFAULT 0,
  avg_speed_kmh double precision NOT NULL DEFAULT 0,
  max_speed_kmh double precision NOT NULL DEFAULT 0,
  xp_earned integer NOT NULL DEFAULT 0,
  is_live_go boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_rides_user_id ON rides(user_id);
CREATE INDEX IF NOT EXISTS idx_rides_started_at ON rides(started_at DESC);

-- RLS
ALTER TABLE rides ENABLE ROW LEVEL SECURITY;

-- Users can read their own rides
CREATE POLICY "Users can read own rides"
  ON rides FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own rides
CREATE POLICY "Users can insert own rides"
  ON rides FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Add is_sold column to marketplace_listings if missing
ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS is_sold boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_marketplace_is_sold ON marketplace_listings(user_id, is_sold);
