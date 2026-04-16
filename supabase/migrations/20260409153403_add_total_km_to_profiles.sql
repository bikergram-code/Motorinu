-- Add total_km to profiles so other users can see ride stats
-- (rides table is blocked by RLS for non-owners)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_km double precision DEFAULT 0;

-- Backfill from existing rides data
UPDATE profiles p
SET total_km = COALESCE((
  SELECT SUM(r.distance_km)
  FROM rides r
  WHERE r.user_id = p.id
), 0);
