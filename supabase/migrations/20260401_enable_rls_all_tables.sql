-- ============================================================================
-- RLS (Row-Level Security) für ALLE public Tabellen aktivieren
-- Datum: 2026-04-01
-- Grund: Supabase Security Alert — Tabellen ohne RLS sind öffentlich zugänglich
-- ============================================================================

-- ─── PROFILES ────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Jeder kann Profile sehen (für Feed, Suche, etc.)
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

-- Nur eigenes Profil bearbeiten
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Nur eigenes Profil erstellen (bei Registrierung)
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ─── POSTS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Öffentliche Posts kann jeder sehen
CREATE POLICY "posts_select_public" ON public.posts
  FOR SELECT USING (
    visibility IS NULL OR visibility = 'public'
    OR user_id = auth.uid()
  );

-- Nur eigene Posts erstellen
CREATE POLICY "posts_insert_own" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Nur eigene Posts bearbeiten
CREATE POLICY "posts_update_own" ON public.posts
  FOR UPDATE USING (auth.uid() = user_id);

-- Nur eigene Posts löschen
CREATE POLICY "posts_delete_own" ON public.posts
  FOR DELETE USING (auth.uid() = user_id);

-- ─── COMMENTS ────────────────────────────────────────────────────────────────
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select_all" ON public.comments
  FOR SELECT USING (true);

CREATE POLICY "comments_insert_auth" ON public.comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_update_own" ON public.comments
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "comments_delete_own" ON public.comments
  FOR DELETE USING (auth.uid() = user_id);

-- ─── POST_LIKES ──────────────────────────────────────────────────────────────
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_likes_select_all" ON public.post_likes
  FOR SELECT USING (true);

CREATE POLICY "post_likes_insert_own" ON public.post_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_likes_delete_own" ON public.post_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ─── FOLLOWS ─────────────────────────────────────────────────────────────────
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "follows_select_all" ON public.follows
  FOR SELECT USING (true);

CREATE POLICY "follows_insert_own" ON public.follows
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_delete_own" ON public.follows
  FOR DELETE USING (auth.uid() = follower_id);

-- ─── VEHICLES ────────────────────────────────────────────────────────────────
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Jeder kann Fahrzeuge sehen (Garage ist öffentlich)
CREATE POLICY "vehicles_select_all" ON public.vehicles
  FOR SELECT USING (true);

CREATE POLICY "vehicles_insert_own" ON public.vehicles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "vehicles_update_own" ON public.vehicles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "vehicles_delete_own" ON public.vehicles
  FOR DELETE USING (auth.uid() = user_id);

-- ─── CONVERSATIONS ───────────────────────────────────────────────────────────
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- Nur Teilnehmer können Konversationen sehen
CREATE POLICY "conversations_select_participant" ON public.conversations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "conversations_insert_auth" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conversations_delete_participant" ON public.conversations
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = id AND cp.user_id = auth.uid()
    )
  );

-- ─── CONVERSATION_PARTICIPANTS ───────────────────────────────────────────────
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

-- Nur eigene Teilnahmen sehen
CREATE POLICY "conv_participants_select_own" ON public.conversation_participants
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "conv_participants_insert_auth" ON public.conversation_participants
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conv_participants_update_own" ON public.conversation_participants
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "conv_participants_delete_own" ON public.conversation_participants
  FOR DELETE USING (user_id = auth.uid());

-- ─── MESSAGES ────────────────────────────────────────────────────────────────
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Nur Nachrichten aus eigenen Konversationen sehen
CREATE POLICY "messages_select_participant" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = conversation_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_insert_participant" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.conversation_participants cp
      WHERE cp.conversation_id = conversation_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "messages_update_own" ON public.messages
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "messages_delete_own" ON public.messages
  FOR DELETE USING (auth.uid() = user_id);

-- ─── NOTIFICATIONS ───────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Nur eigene Benachrichtigungen sehen
CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Andere können Notifications für einen User erstellen
CREATE POLICY "notifications_insert_auth" ON public.notifications
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id != auth.uid());

-- Nur eigene als gelesen markieren
CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ─── STORIES ─────────────────────────────────────────────────────────────────
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stories_select_all" ON public.stories
  FOR SELECT USING (true);

CREATE POLICY "stories_insert_own" ON public.stories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "stories_delete_own" ON public.stories
  FOR DELETE USING (auth.uid() = user_id);

-- ─── STORY_COMMENTS ──────────────────────────────────────────────────────────
ALTER TABLE public.story_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "story_comments_select_all" ON public.story_comments
  FOR SELECT USING (true);

CREATE POLICY "story_comments_insert_auth" ON public.story_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "story_comments_delete_own" ON public.story_comments
  FOR DELETE USING (auth.uid() = user_id);

-- ─── STORY_LIKES ─────────────────────────────────────────────────────────────
ALTER TABLE public.story_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "story_likes_select_all" ON public.story_likes
  FOR SELECT USING (true);

CREATE POLICY "story_likes_insert_own" ON public.story_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "story_likes_delete_own" ON public.story_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ─── EVENTS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "events_select_all" ON public.events
  FOR SELECT USING (true);

CREATE POLICY "events_insert_auth" ON public.events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "events_update_own" ON public.events
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "events_delete_own" ON public.events
  FOR DELETE USING (auth.uid() = user_id);

-- ─── EVENT_PARTICIPANTS ──────────────────────────────────────────────────────
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "event_participants_select_all" ON public.event_participants
  FOR SELECT USING (true);

CREATE POLICY "event_participants_insert_own" ON public.event_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "event_participants_delete_own" ON public.event_participants
  FOR DELETE USING (auth.uid() = user_id);

-- ─── MARKETPLACE_LISTINGS ────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "marketplace_select_all" ON public.marketplace_listings
  FOR SELECT USING (true);

CREATE POLICY "marketplace_insert_own" ON public.marketplace_listings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "marketplace_update_own" ON public.marketplace_listings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "marketplace_delete_own" ON public.marketplace_listings
  FOR DELETE USING (auth.uid() = user_id);

-- ─── MEETUPS ─────────────────────────────────────────────────────────────────
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meetups_select_all" ON public.meetups
  FOR SELECT USING (true);

-- ─── BLITZER_REPORTS ─────────────────────────────────────────────────────────
ALTER TABLE public.blitzer_reports ENABLE ROW LEVEL SECURITY;

-- Alle aktiven Blitzer sichtbar
CREATE POLICY "blitzer_reports_select_all" ON public.blitzer_reports
  FOR SELECT USING (true);

CREATE POLICY "blitzer_reports_insert_auth" ON public.blitzer_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "blitzer_reports_update_own" ON public.blitzer_reports
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "blitzer_reports_delete_own" ON public.blitzer_reports
  FOR DELETE USING (auth.uid() = user_id);

-- ─── RIDES ───────────────────────────────────────────────────────────────────
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

-- Nur eigene Rides sehen
CREATE POLICY "rides_select_own" ON public.rides
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "rides_insert_own" ON public.rides
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ─── DIRECT_MESSAGES (falls vorhanden) ───────────────────────────────────────
-- direct_messages nutzt user_id (nicht sender_id/receiver_id)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages' AND table_schema = 'public') THEN
    EXECUTE 'ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY';
    EXECUTE 'CREATE POLICY "dm_select_participant" ON public.direct_messages FOR SELECT USING (
      EXISTS (
        SELECT 1 FROM public.conversation_participants cp
        WHERE cp.conversation_id = direct_messages.conversation_id AND cp.user_id = auth.uid()
      )
    )';
    EXECUTE 'CREATE POLICY "dm_insert_own" ON public.direct_messages FOR INSERT WITH CHECK (auth.uid() = user_id)';
  END IF;
END $$;

-- ─── POI_RATINGS ─────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'poi_ratings' AND table_schema = 'public') THEN
    EXECUTE 'ALTER TABLE public.poi_ratings ENABLE ROW LEVEL SECURITY';
    EXECUTE 'CREATE POLICY "poi_ratings_select_all" ON public.poi_ratings FOR SELECT USING (true)';
    EXECUTE 'CREATE POLICY "poi_ratings_insert_own" ON public.poi_ratings FOR INSERT WITH CHECK (auth.uid() = user_id)';
  END IF;
END $$;

-- ============================================================================
-- HINWEIS: Tabellen die bereits RLS haben (vehicle_likes, vehicle_offers,
-- user_devices, media_assets, post_media, topics, post_topics, groups,
-- group_members, etc.) werden nicht erneut verändert.
--
-- ALTER TABLE ... ENABLE ROW LEVEL SECURITY ist idempotent — wenn RLS
-- bereits aktiv ist, passiert nichts. CREATE POLICY schlägt fehl wenn
-- der Policy-Name bereits existiert — daher nur neue Tabellen hier.
-- ============================================================================
