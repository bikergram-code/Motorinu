-- ============================================================================
-- BIKERGRAM / CARGRAM - Supabase Database Schema
-- ============================================================================
-- Run in: Supabase Dashboard > SQL Editor > New Query > Paste > Run
-- ============================================================================

-- 1. PROFILES
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique,
  display_name text,
  bikername text,
  email text,
  avatar_url text,
  bio text,
  postal_code text,
  community text default 'bikergram' check (community in ('bikergram', 'cargram')),
  xp_total int default 0,
  level int default 1,
  birth_year int,
  moto_start_age int,
  car_start_age int,
  has_track_experience boolean default false,
  is_premium boolean default false,
  is_business boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- 2. POSTS
create table if not exists public.posts (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  body text,
  image_url text,
  video_url text,
  attachment_urls text[] default '{}',
  community text default 'bikergram' check (community in ('bikergram', 'cargram')),
  like_count int default 0,
  comment_count int default 0,
  is_promoted boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table public.posts enable row level security;
create policy "posts_select" on public.posts for select using (true);
create policy "posts_insert" on public.posts for insert with check (auth.uid() = user_id);
create policy "posts_update" on public.posts for update using (auth.uid() = user_id);
create policy "posts_delete" on public.posts for delete using (auth.uid() = user_id);

-- 3. POST LIKES
create table if not exists public.post_likes (
  id bigint generated always as identity primary key,
  post_id bigint references public.posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);
alter table public.post_likes enable row level security;
create policy "likes_select" on public.post_likes for select using (true);
create policy "likes_insert" on public.post_likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.post_likes for delete using (auth.uid() = user_id);

-- 4. COMMENTS
create table if not exists public.comments (
  id bigint generated always as identity primary key,
  post_id bigint references public.posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  parent_id bigint references public.comments(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);
alter table public.comments enable row level security;
create policy "comments_select" on public.comments for select using (true);
create policy "comments_insert" on public.comments for insert with check (auth.uid() = user_id);
create policy "comments_delete" on public.comments for delete using (auth.uid() = user_id);

-- 5. VEHICLES
create table if not exists public.vehicles (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  community text default 'bikergram' check (community in ('bikergram', 'cargram')),
  brand text not null,
  model text not null,
  year int,
  displacement_cc int,
  horsepower int,
  category text,
  image_url text,
  is_primary boolean default false,
  created_at timestamptz default now()
);
alter table public.vehicles enable row level security;
create policy "vehicles_select" on public.vehicles for select using (true);
create policy "vehicles_insert" on public.vehicles for insert with check (auth.uid() = user_id);
create policy "vehicles_update" on public.vehicles for update using (auth.uid() = user_id);
create policy "vehicles_delete" on public.vehicles for delete using (auth.uid() = user_id);

-- 6. RIDES
create table if not exists public.rides (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  vehicle_id bigint references public.vehicles(id) on delete set null,
  title text,
  distance_km numeric(10,2) default 0,
  duration_seconds int default 0,
  avg_speed_kmh numeric(6,2) default 0,
  max_speed_kmh numeric(6,2) default 0,
  xp_earned int default 0,
  route_data jsonb,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz default now()
);
alter table public.rides enable row level security;
create policy "rides_select" on public.rides for select using (auth.uid() = user_id);
create policy "rides_insert" on public.rides for insert with check (auth.uid() = user_id);
create policy "rides_update" on public.rides for update using (auth.uid() = user_id);
create policy "rides_delete" on public.rides for delete using (auth.uid() = user_id);

-- 7. FOLLOWS
create table if not exists public.follows (
  id bigint generated always as identity primary key,
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(follower_id, following_id)
);
alter table public.follows enable row level security;
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

-- 8. BLITZER
create table if not exists public.blitzer_reports (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  latitude numeric(10,7) not null,
  longitude numeric(10,7) not null,
  type text default 'fixed' check (type in ('fixed', 'mobile', 'construction', 'accident')),
  description text,
  confirmations int default 1,
  dismissals int default 0,
  is_active boolean default true,
  expires_at timestamptz,
  created_at timestamptz default now()
);
alter table public.blitzer_reports enable row level security;
create policy "blitzer_select" on public.blitzer_reports for select using (is_active = true);
create policy "blitzer_insert" on public.blitzer_reports for insert with check (auth.uid() = user_id);
create policy "blitzer_update" on public.blitzer_reports for update using (auth.uid() = user_id);

-- 9. MARKETPLACE
create table if not exists public.marketplace_listings (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text,
  price numeric(10,2),
  currency text default 'EUR',
  category text,
  condition text check (condition in ('new', 'like_new', 'good', 'fair', 'parts')),
  community text default 'bikergram' check (community in ('bikergram', 'cargram')),
  images text[] default '{}',
  location_text text,
  is_sold boolean default false,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table public.marketplace_listings enable row level security;
create policy "listings_select" on public.marketplace_listings for select using (is_active = true);
create policy "listings_insert" on public.marketplace_listings for insert with check (auth.uid() = user_id);
create policy "listings_update" on public.marketplace_listings for update using (auth.uid() = user_id);
create policy "listings_delete" on public.marketplace_listings for delete using (auth.uid() = user_id);

-- 10. CONVERSATIONS & MESSAGES
create table if not exists public.conversations (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create table if not exists public.conversation_participants (
  conversation_id bigint references public.conversations(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  joined_at timestamptz default now(),
  primary key (conversation_id, user_id)
);
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  conversation_id bigint references public.conversations(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  body text,
  image_url text,
  is_read boolean default false,
  created_at timestamptz default now()
);
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
-- SELECT: User kann nur Konversationen sehen, an denen er teilnimmt
create policy "convos_select" on public.conversations for select using (
  id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
);
-- INSERT: Jeder eingeloggte User kann eine neue Konversation erstellen
create policy "convos_insert" on public.conversations for insert with check (true);
-- UPDATE: User kann Konversationen updaten (z.B. updated_at), an denen er teilnimmt
create policy "convos_update" on public.conversations for update using (
  id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
);

-- SELECT: Teilnehmer-Daten sind lesbar (Konversations-Zugriff wird ueber convos_select gesteuert)
create policy "participants_select" on public.conversation_participants for select using (true);
-- INSERT: User kann Teilnehmer hinzufuegen (sich selbst oder andere beim Erstellen)
create policy "participants_insert" on public.conversation_participants for insert with check (true);

-- SELECT: User sieht Nachrichten aus seinen Konversationen
create policy "messages_select" on public.messages for select using (
  conversation_id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
);
-- INSERT: User kann Nachrichten senden in Konversationen, an denen er teilnimmt
create policy "messages_insert" on public.messages for insert with check (
  auth.uid() = user_id and
  conversation_id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
);
-- UPDATE: User kann Nachrichten in seinen Konversationen updaten (z.B. is_read)
create policy "messages_update" on public.messages for update using (
  conversation_id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
);

-- 11. NOTIFICATIONS
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  type text not null check (type in ('like', 'comment', 'follow', 'mention', 'xp', 'system')),
  title text not null,
  body text,
  data jsonb default '{}',
  is_read boolean default false,
  created_at timestamptz default now()
);
alter table public.notifications enable row level security;
create policy "notif_select" on public.notifications for select using (auth.uid() = user_id);
create policy "notif_update" on public.notifications for update using (auth.uid() = user_id);

-- 12. XP TRANSACTIONS
create table if not exists public.xp_transactions (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount int not null,
  reason text not null,
  metadata jsonb default '{}',
  created_at timestamptz default now()
);
alter table public.xp_transactions enable row level security;
create policy "xp_select" on public.xp_transactions for select using (auth.uid() = user_id);

-- 13. STORIES
create table if not exists public.stories (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  media_url text not null,
  media_type text default 'image' check (media_type in ('image', 'video')),
  caption text,
  view_count int default 0,
  expires_at timestamptz default (now() + interval '24 hours'),
  created_at timestamptz default now()
);
alter table public.stories enable row level security;
create policy "stories_select" on public.stories for select using (expires_at > now());
create policy "stories_insert" on public.stories for insert with check (auth.uid() = user_id);
create policy "stories_delete" on public.stories for delete using (auth.uid() = user_id);

-- 14. POST SAVES (Bookmarks)
create table if not exists public.post_saves (
  id bigint generated always as identity primary key,
  post_id bigint references public.posts(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);
alter table public.post_saves enable row level security;
create policy "saves_select" on public.post_saves for select using (auth.uid() = user_id);
create policy "saves_insert" on public.post_saves for insert with check (auth.uid() = user_id);
create policy "saves_delete" on public.post_saves for delete using (auth.uid() = user_id);
create index if not exists idx_saves_user on public.post_saves(user_id);
create index if not exists idx_saves_post on public.post_saves(post_id);

-- 15. EVENTS
create table if not exists public.events (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text,
  location_text text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  starts_at timestamptz not null,
  ends_at timestamptz,
  community text default 'bikergram' check (community in ('bikergram', 'cargram')),
  max_participants int,
  image_url text,
  created_at timestamptz default now()
);
create table if not exists public.event_participants (
  event_id bigint references public.events(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  status text default 'going' check (status in ('going', 'interested', 'not_going')),
  joined_at timestamptz default now(),
  primary key (event_id, user_id)
);
alter table public.events enable row level security;
alter table public.event_participants enable row level security;
create policy "events_select" on public.events for select using (true);
create policy "events_insert" on public.events for insert with check (auth.uid() = user_id);
create policy "events_update" on public.events for update using (auth.uid() = user_id);
create policy "events_delete" on public.events for delete using (auth.uid() = user_id);
create policy "ep_select" on public.event_participants for select using (true);
create policy "ep_insert" on public.event_participants for insert with check (auth.uid() = user_id);
create policy "ep_delete" on public.event_participants for delete using (auth.uid() = user_id);
create policy "ep_update" on public.event_participants for update using (auth.uid() = user_id);

-- 15. AUTO-CREATE PROFILE ON SIGNUP
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, username, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 16. TOGGLE LIKE (RPC)
create or replace function public.toggle_like(p_post_id bigint)
returns json as $$
declare
  v_liked boolean;
begin
  if exists (select 1 from public.post_likes where post_id = p_post_id and user_id = auth.uid()) then
    delete from public.post_likes where post_id = p_post_id and user_id = auth.uid();
    update public.posts set like_count = greatest(0, like_count - 1) where id = p_post_id;
    v_liked := false;
  else
    insert into public.post_likes (post_id, user_id) values (p_post_id, auth.uid());
    update public.posts set like_count = like_count + 1 where id = p_post_id;
    v_liked := true;
  end if;
  return json_build_object('liked', v_liked, 'post_id', p_post_id);
end;
$$ language plpgsql security definer;

-- 17. INDEXES
create index if not exists idx_posts_user on public.posts(user_id);
create index if not exists idx_posts_community on public.posts(community);
create index if not exists idx_posts_created on public.posts(created_at desc);
create index if not exists idx_likes_post on public.post_likes(post_id);
create index if not exists idx_likes_user on public.post_likes(user_id);
create index if not exists idx_comments_post on public.comments(post_id);
create index if not exists idx_follows_er on public.follows(follower_id);
create index if not exists idx_follows_ing on public.follows(following_id);
create index if not exists idx_vehicles_user on public.vehicles(user_id);
create index if not exists idx_rides_user on public.rides(user_id);
create index if not exists idx_blitzer_loc on public.blitzer_reports(latitude, longitude);
create index if not exists idx_messages_conv on public.messages(conversation_id);
create index if not exists idx_notif_user on public.notifications(user_id);
