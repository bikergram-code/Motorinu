-- Migration: Add reaction types to post_likes
-- Reactions: fire, love, laugh, motorcycle, thumbs_up, wow
-- NULL reaction_type = regular like (backward compatible)

-- 1. Add reaction_type column to post_likes
ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS reaction_type text DEFAULT NULL
  CHECK (reaction_type IS NULL OR reaction_type IN ('fire', 'love', 'laugh', 'motorcycle', 'thumbs_up', 'wow'));

-- 2. Index for aggregating reactions per post
CREATE INDEX IF NOT EXISTS idx_post_likes_reaction ON post_likes (post_id, reaction_type);

-- 3. New RPC: toggle_reaction (replaces/extends toggle_like)
-- If user already has the same reaction → remove it
-- If user has a different reaction → change it
-- If user has no reaction → add it
CREATE OR REPLACE FUNCTION public.toggle_reaction(p_post_id bigint, p_reaction text DEFAULT NULL)
RETURNS json AS $$
DECLARE
  v_existing_reaction text;
  v_exists boolean;
BEGIN
  -- Check if user already has a like/reaction on this post
  SELECT reaction_type INTO v_existing_reaction
  FROM public.post_likes
  WHERE post_id = p_post_id AND user_id = auth.uid();

  v_exists := FOUND;

  IF v_exists THEN
    IF v_existing_reaction IS NOT DISTINCT FROM p_reaction THEN
      -- Same reaction (or both NULL) → toggle off (remove)
      DELETE FROM public.post_likes WHERE post_id = p_post_id AND user_id = auth.uid();
      UPDATE public.posts SET like_count = GREATEST(0, like_count - 1) WHERE id = p_post_id;
      RETURN json_build_object('liked', false, 'reaction', NULL, 'post_id', p_post_id);
    ELSE
      -- Different reaction → update in place (no count change)
      UPDATE public.post_likes SET reaction_type = p_reaction
      WHERE post_id = p_post_id AND user_id = auth.uid();
      RETURN json_build_object('liked', true, 'reaction', p_reaction, 'post_id', p_post_id);
    END IF;
  ELSE
    -- No existing → insert new
    INSERT INTO public.post_likes (post_id, user_id, reaction_type)
    VALUES (p_post_id, auth.uid(), p_reaction);
    UPDATE public.posts SET like_count = like_count + 1 WHERE id = p_post_id;
    RETURN json_build_object('liked', true, 'reaction', p_reaction, 'post_id', p_post_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Add thumbnail_url column to posts (for video thumbnails)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS thumbnail_url text;
