-- ============================================================================
-- Blitzer Reports Table + RLS
-- ============================================================================
-- Stellt sicher dass die Tabelle blitzer_reports existiert und User ihre
-- eigenen Reports erstellen können. Sicher mehrfach auszuführen (idempotent).
--
-- Einmalig ausführen: https://supabase.com/dashboard/project/trmwbkpfafigraveneva/sql
-- ============================================================================

create table if not exists public.blitzer_reports (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete cascade,
  latitude    double precision not null,
  longitude   double precision not null,
  type        text not null default 'mobile',
  description text,
  confirmations integer not null default 1,
  dismissals    integer not null default 0,
  is_active     boolean not null default true,
  expires_at    timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists blitzer_reports_active_idx
  on public.blitzer_reports(is_active, created_at desc);
create index if not exists blitzer_reports_location_idx
  on public.blitzer_reports(latitude, longitude);

alter table public.blitzer_reports enable row level security;

-- Alle dürfen lesen (community-basiert)
drop policy if exists "blitzer read all" on public.blitzer_reports;
create policy "blitzer read all"
  on public.blitzer_reports for select
  to authenticated, anon
  using (true);

-- User darf eigene Reports einfügen
drop policy if exists "blitzer insert own" on public.blitzer_reports;
create policy "blitzer insert own"
  on public.blitzer_reports for insert
  to authenticated
  with check (auth.uid() = user_id);

-- User darf eigene Reports updaten (confirm/dismiss)
drop policy if exists "blitzer update own" on public.blitzer_reports;
create policy "blitzer update own"
  on public.blitzer_reports for update
  to authenticated
  using (true)
  with check (true);

-- User darf eigene Reports löschen
drop policy if exists "blitzer delete own" on public.blitzer_reports;
create policy "blitzer delete own"
  on public.blitzer_reports for delete
  to authenticated
  using (auth.uid() = user_id);
