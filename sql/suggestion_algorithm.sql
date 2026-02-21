-- ============================================================
-- Smarter Vorschlags-Algorithmus fuer User-Suche
-- Bitte im Supabase SQL-Editor ausfuehren
-- SICHER: Kann mehrfach ausgefuehrt werden (CREATE OR REPLACE)
-- ============================================================
--
-- Scoring-System (max 100 Punkte):
--   PLZ gleich (5 Stellen)  = 50 Punkte (selber Ort)
--   PLZ 3-stellig gleich    = 40 Punkte (~20km)
--   PLZ 2-stellig gleich    = 30 Punkte (~50km)
--   PLZ 1-stellig gleich    = 15 Punkte (~100km)
--   Aktivitaet (XP)         = 0-20 Punkte
--   Freund eines Freundes   = 30 Punkte
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_suggested_users(
  p_limit int DEFAULT 20
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_plz text;
  v_community text;
BEGIN
  -- Eigene Daten laden
  SELECT postal_code, community
  INTO v_plz, v_community
  FROM public.profiles
  WHERE id = v_user_id;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'username', p.username,
    'display_name', p.display_name,
    'bikername', p.bikername,
    'bio', p.bio,
    'avatar_url', p.avatar_url,
    'avatar_url_cargram', p.avatar_url_cargram,
    'level', p.level,
    'is_premium', p.is_premium,
    'is_business', p.is_business,
    'community', p.community,
    'postal_code', p.postal_code,
    'score', (
      -- PLZ-Naehe Score (0-50 Punkte)
      CASE
        WHEN v_plz IS NOT NULL AND p.postal_code IS NOT NULL THEN
          CASE
            WHEN p.postal_code = v_plz THEN 50
            WHEN LEFT(p.postal_code, 3) = LEFT(v_plz, 3) THEN 40
            WHEN LEFT(p.postal_code, 2) = LEFT(v_plz, 2) THEN 30
            WHEN LEFT(p.postal_code, 1) = LEFT(v_plz, 1) THEN 15
            ELSE 0
          END
        ELSE 0
      END
      -- Aktivitaet Score (0-20 Punkte)
      + LEAST(COALESCE(p.xp_total, 0) / 100, 20)
      -- Freunde-von-Freunden Score (0-30 Punkte)
      + CASE
          WHEN EXISTS (
            SELECT 1 FROM public.follows f1
            JOIN public.follows f2 ON f1.following_id = f2.follower_id
            WHERE f1.follower_id = v_user_id
              AND f2.following_id = p.id
              AND p.id != v_user_id
          ) THEN 30
          ELSE 0
        END
    )
  )
  FROM public.profiles p
  WHERE p.id != v_user_id
    AND (v_community IS NULL OR p.community = v_community)
    AND NOT EXISTS (
      SELECT 1 FROM public.follows
      WHERE follower_id = v_user_id AND following_id = p.id
    )
  ORDER BY (
    CASE
      WHEN v_plz IS NOT NULL AND p.postal_code IS NOT NULL THEN
        CASE
          WHEN p.postal_code = v_plz THEN 50
          WHEN LEFT(p.postal_code, 3) = LEFT(v_plz, 3) THEN 40
          WHEN LEFT(p.postal_code, 2) = LEFT(v_plz, 2) THEN 30
          WHEN LEFT(p.postal_code, 1) = LEFT(v_plz, 1) THEN 15
          ELSE 0
        END
      ELSE 0
    END
    + LEAST(COALESCE(p.xp_total, 0) / 100, 20)
    + CASE
        WHEN EXISTS (
          SELECT 1 FROM public.follows f1
          JOIN public.follows f2 ON f1.following_id = f2.follower_id
          WHERE f1.follower_id = v_user_id
            AND f2.following_id = p.id
        ) THEN 30
        ELSE 0
      END
  ) DESC
  LIMIT p_limit;
END;
$$;
