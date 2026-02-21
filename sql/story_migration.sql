-- ============================================================
-- Story-Erweiterungen: Likes, Kommentare, Follower-Only RLS
-- Bitte im Supabase SQL-Editor ausfuehren
-- SICHER: Kann mehrfach ausgefuehrt werden (idempotent)
-- ============================================================

-- A) RLS-Policy aendern — Stories nur fuer Follower + Ersteller sichtbar
drop policy if exists "stories_select" on public.stories;
create policy "stories_select" on public.stories for select using (
  expires_at > now() AND (
    auth.uid() = user_id
    OR exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = stories.user_id
    )
  )
);

-- B) Neue Spalten in stories
alter table public.stories add column if not exists like_count int default 0;
alter table public.stories add column if not exists comment_count int default 0;

-- C) Neue Tabelle: story_likes
create table if not exists public.story_likes (
  id bigint generated always as identity primary key,
  story_id bigint references public.stories(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(story_id, user_id)
);
alter table public.story_likes enable row level security;

-- Policies droppen falls vorhanden, dann neu anlegen
drop policy if exists "story_likes_select" on public.story_likes;
drop policy if exists "story_likes_insert" on public.story_likes;
drop policy if exists "story_likes_delete" on public.story_likes;
create policy "story_likes_select" on public.story_likes for select using (true);
create policy "story_likes_insert" on public.story_likes for insert with check (auth.uid() = user_id);
create policy "story_likes_delete" on public.story_likes for delete using (auth.uid() = user_id);

-- D) Neue Tabelle: story_comments
create table if not exists public.story_comments (
  id bigint generated always as identity primary key,
  story_id bigint references public.stories(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  body text not null,
  created_at timestamptz default now()
);
alter table public.story_comments enable row level security;

-- Policies droppen falls vorhanden, dann neu anlegen
drop policy if exists "story_comments_select" on public.story_comments;
drop policy if exists "story_comments_insert" on public.story_comments;
drop policy if exists "story_comments_delete" on public.story_comments;
create policy "story_comments_select" on public.story_comments for select using (true);
create policy "story_comments_insert" on public.story_comments for insert with check (auth.uid() = user_id);
create policy "story_comments_delete" on public.story_comments for delete using (auth.uid() = user_id);

-- E) RPC: toggle_story_like (CREATE OR REPLACE = idempotent)
create or replace function public.toggle_story_like(p_story_id bigint)
returns json language plpgsql security definer as $$
declare
  v_user_id uuid := auth.uid();
  v_exists boolean;
begin
  select exists(
    select 1 from public.story_likes where story_id = p_story_id and user_id = v_user_id
  ) into v_exists;

  if v_exists then
    delete from public.story_likes where story_id = p_story_id and user_id = v_user_id;
    update public.stories set like_count = greatest(like_count - 1, 0) where id = p_story_id;
    return json_build_object('liked', false, 'story_id', p_story_id);
  else
    insert into public.story_likes(story_id, user_id) values(p_story_id, v_user_id);
    update public.stories set like_count = like_count + 1 where id = p_story_id;
    return json_build_object('liked', true, 'story_id', p_story_id);
  end if;
end;
$$;
