-- ============================================================
-- Migration: Fix comment counts + ensure post_saves table
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Ensure post_saves table exists with correct RLS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.post_saves (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id bigint REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

ALTER TABLE public.post_saves ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid "already exists" errors
DROP POLICY IF EXISTS "saves_select" ON public.post_saves;
DROP POLICY IF EXISTS "saves_insert" ON public.post_saves;
DROP POLICY IF EXISTS "saves_delete" ON public.post_saves;

CREATE POLICY "saves_select" ON public.post_saves FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "saves_insert" ON public.post_saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "saves_delete" ON public.post_saves FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_saves_user ON public.post_saves(user_id);
CREATE INDEX IF NOT EXISTS idx_saves_post ON public.post_saves(post_id);


-- 2. Ensure comment_count column exists on posts
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'comment_count'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN comment_count int DEFAULT 0;
  END IF;
END $$;


-- 3. Backfill comment_count from actual comments
-- ============================================================
UPDATE public.posts p
SET comment_count = COALESCE(sub.cnt, 0)
FROM (
  SELECT post_id, COUNT(*) AS cnt
  FROM public.comments
  GROUP BY post_id
) sub
WHERE p.id = sub.post_id
  AND p.comment_count != sub.cnt;

-- Also set 0 for posts with no comments (just in case)
UPDATE public.posts
SET comment_count = 0
WHERE id NOT IN (SELECT DISTINCT post_id FROM public.comments)
  AND comment_count != 0;


-- 4. Create trigger to auto-update comment_count on insert/delete
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_comment_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts
    SET comment_count = comment_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts
    SET comment_count = GREATEST(comment_count - 1, 0)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_comment_count ON public.comments;
CREATE TRIGGER trg_comment_count
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_comment_count();


-- 5. Ensure save_count column exists (optional counter)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'save_count'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN save_count int DEFAULT 0;
  END IF;
END $$;


-- 6. Ensure view_count, repost_count columns exist
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'view_count'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN view_count int DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'repost_count'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN repost_count int DEFAULT 0;
  END IF;
END $$;


-- 7. Ensure thumbnail_url column exists
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'thumbnail_url'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN thumbnail_url text;
  END IF;
END $$;


-- 8. Ensure media_type column exists
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'media_type'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN media_type text DEFAULT 'image';
  END IF;
END $$;


-- 9. Ensure visibility column exists
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'visibility'
  ) THEN
    ALTER TABLE public.posts ADD COLUMN visibility text DEFAULT 'public';
  END IF;
END $$;


-- 10. Ensure reaction_type column in post_likes
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'post_likes' AND column_name = 'reaction_type'
  ) THEN
    ALTER TABLE public.post_likes ADD COLUMN reaction_type text;
  END IF;
END $$;


-- 11. Ensure feed_events table exists (analytics)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.feed_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  event_type text NOT NULL,
  post_id bigint REFERENCES public.posts(id) ON DELETE CASCADE,
  properties jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.feed_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "feed_events_insert" ON public.feed_events;
CREATE POLICY "feed_events_insert" ON public.feed_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "feed_events_select" ON public.feed_events;
CREATE POLICY "feed_events_select" ON public.feed_events
  FOR SELECT USING (auth.uid() = user_id);


-- Done! ✓
-- All tables and columns should now exist.
-- comment_count is backfilled from actual comments.
-- Future comments auto-update the count via trigger.
-- post_saves table is ready for bookmark functionality.
