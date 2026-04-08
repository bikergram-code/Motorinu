-- ============================================================================
-- Bug Reports Storage Bucket
-- ============================================================================
-- Fix für "StorageException: Bucket not found, statusCode: 404"
-- Erstellt den Bucket 'bug-reports' + RLS Policies für Screenshot-Uploads.
--
-- Einmalig in Supabase SQL Editor ausführen:
--   https://supabase.com/dashboard/project/trmwbkpfafigraveneva/sql
-- ============================================================================

-- Bucket erstellen (public = true damit Screenshots per URL abrufbar sind)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bug-reports',
  'bug-reports',
  true,
  10485760, -- 10 MB pro File
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- RLS Policies
-- 1. Authentifizierte User dürfen in ihren eigenen Ordner uploaden
drop policy if exists "bug-reports upload own" on storage.objects;
create policy "bug-reports upload own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'bug-reports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 2. Alle dürfen Bilder lesen (public bucket)
drop policy if exists "bug-reports read all" on storage.objects;
create policy "bug-reports read all"
  on storage.objects for select
  to public
  using (bucket_id = 'bug-reports');

-- 3. User dürfen ihre eigenen Bilder löschen
drop policy if exists "bug-reports delete own" on storage.objects;
create policy "bug-reports delete own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'bug-reports'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================================
-- bug_reports Tabelle (falls noch nicht existiert)
-- ============================================================================
create table if not exists public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  description text not null,
  screenshot_urls text[] default '{}',
  device_info jsonb,
  app_version text,
  created_at timestamptz default now(),
  status text default 'open'
);

alter table public.bug_reports enable row level security;

drop policy if exists "bug_reports insert own" on public.bug_reports;
create policy "bug_reports insert own"
  on public.bug_reports for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "bug_reports read own" on public.bug_reports;
create policy "bug_reports read own"
  on public.bug_reports for select
  to authenticated
  using (auth.uid() = user_id);
