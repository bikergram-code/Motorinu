-- ============================================================================
-- Account-Löschung: Self-Service Function
-- ============================================================================
-- Erlaubt eingeloggten Usern ihr eigenes Konto + alle Daten zu löschen.
-- Aufruf vom Client: supabase.rpc('delete_my_account')
--
-- Security: SECURITY DEFINER + auth.uid() — User kann nur sich selbst löschen.
--
-- Einmalig in Supabase SQL Editor ausführen:
--   https://supabase.com/dashboard/project/trmwbkpfafigraveneva/sql
-- ============================================================================

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Alle bekannten User-Daten löschen.
  -- Jeder Block in EXCEPTION WHEN OTHERS gekapselt, damit fehlende
  -- Tabellen/Spalten die Löschung nicht abbrechen.

  begin delete from xp_transactions where user_id = uid; exception when others then null; end;
  begin delete from notifications where user_id = uid; exception when others then null; end;
  begin delete from notifications where actor_id = uid; exception when others then null; end;
  begin delete from notifications where sender_id = uid; exception when others then null; end;
  begin delete from notifications where from_user_id = uid; exception when others then null; end;
  begin delete from messages where sender_id = uid; exception when others then null; end;
  begin delete from messages where user_id = uid; exception when others then null; end;
  begin delete from conversation_participants where user_id = uid; exception when others then null; end;
  begin delete from follows where follower_id = uid; exception when others then null; end;
  begin delete from follows where followed_id = uid; exception when others then null; end;
  begin delete from follows where following_id = uid; exception when others then null; end;
  begin delete from post_likes where user_id = uid; exception when others then null; end;
  begin delete from likes where user_id = uid; exception when others then null; end;
  begin delete from comments where user_id = uid; exception when others then null; end;
  begin delete from posts where user_id = uid; exception when others then null; end;
  begin delete from stories where user_id = uid; exception when others then null; end;
  begin delete from story_likes where user_id = uid; exception when others then null; end;
  begin delete from story_comments where user_id = uid; exception when others then null; end;
  begin delete from saved_posts where user_id = uid; exception when others then null; end;
  begin delete from rides where user_id = uid; exception when others then null; end;
  begin delete from marketplace_listings where user_id = uid; exception when others then null; end;
  begin delete from marketplace_items where user_id = uid; exception when others then null; end;
  begin delete from group_members where user_id = uid; exception when others then null; end;
  begin delete from groups where owner_id = uid; exception when others then null; end;
  begin delete from event_attendees where user_id = uid; exception when others then null; end;
  begin delete from events where user_id = uid; exception when others then null; end;
  begin delete from events where owner_id = uid; exception when others then null; end;
  begin delete from live_sessions where user_id = uid; exception when others then null; end;
  begin delete from dating_likes where user_id = uid; exception when others then null; end;
  begin delete from dating_likes where target_user_id = uid; exception when others then null; end;
  begin delete from user_reports where reporter_id = uid; exception when others then null; end;
  begin delete from user_reports where reported_user_id = uid; exception when others then null; end;
  begin delete from bug_reports where user_id = uid; exception when others then null; end;
  begin delete from profiles where id = uid; exception when others then null; end;

  -- Schließlich den Auth-User selbst löschen
  delete from auth.users where id = uid;
end;
$$;

-- Berechtigung: nur authentifizierte User dürfen die Function aufrufen
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
