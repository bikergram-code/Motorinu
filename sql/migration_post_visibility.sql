-- Migration: Add visibility column to posts table
-- Values: 'public' (everyone), 'followers' (only followers), 'private' (only author)

ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'public'
  CHECK (visibility IN ('public', 'followers', 'private'));

-- Index for fast filtering
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts (visibility);

-- Update RLS policies to respect visibility
-- Drop existing select policy if any, then recreate
DO $$
BEGIN
  -- Check if policy exists and drop it
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'posts' AND policyname = 'Posts are viewable by everyone'
  ) THEN
    DROP POLICY "Posts are viewable by everyone" ON posts;
  END IF;
END $$;

-- New policy: public posts visible to all, followers posts only to followers, private only to author
CREATE POLICY "Posts visibility" ON posts FOR SELECT USING (
  visibility = 'public'
  OR (visibility = 'followers' AND (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM follows
      WHERE follows.follower_id = auth.uid()
        AND follows.following_id = posts.user_id
    )
  ))
  OR (visibility = 'private' AND auth.uid() = user_id)
);
