-- ============================================================================
-- FIX: Messaging-System RLS + RPC-Funktion
-- ============================================================================
-- Ausfuehren in: Supabase Dashboard > SQL Editor > New Query > Paste > Run
-- ============================================================================

-- =============================================
-- SCHRITT 1: RPC-Funktion fuer Konversation erstellen
-- Diese Funktion umgeht RLS mit SECURITY DEFINER,
-- weil INSERT + SELECT in einer Transaktion noetig ist.
-- =============================================
create or replace function public.get_or_create_conversation(other_user_id uuid)
returns bigint as $$
declare
  v_conv_id bigint;
  v_user_id uuid := auth.uid();
begin
  -- Pruefen ob bereits eine Konversation existiert
  select cp1.conversation_id into v_conv_id
  from public.conversation_participants cp1
  join public.conversation_participants cp2
    on cp1.conversation_id = cp2.conversation_id
  where cp1.user_id = v_user_id
    and cp2.user_id = other_user_id
  limit 1;

  -- Falls gefunden, zurueckgeben
  if v_conv_id is not null then
    return v_conv_id;
  end if;

  -- Neue Konversation erstellen
  insert into public.conversations (updated_at)
  values (now())
  returning id into v_conv_id;

  -- Beide Teilnehmer hinzufuegen
  insert into public.conversation_participants (conversation_id, user_id)
  values (v_conv_id, v_user_id), (v_conv_id, other_user_id);

  return v_conv_id;
end;
$$ language plpgsql security definer;

-- =============================================
-- SCHRITT 2: Fehlende RLS-Policies hinzufuegen
-- =============================================

-- conversations: UPDATE (fuer updated_at nach Nachricht senden)
do $$ begin
  create policy "convos_update" on public.conversations
    for update using (
      id in (select conversation_id from public.conversation_participants where user_id = auth.uid())
    );
exception when duplicate_object then null;
end $$;

-- conversation_participants: SELECT erweitern (beide Teilnehmer sehen)
drop policy if exists "participants_select" on public.conversation_participants;
create policy "participants_select" on public.conversation_participants
  for select using (true);

-- conversation_participants: INSERT (fuer RPC-Fallback, falls noetig)
do $$ begin
  create policy "participants_insert" on public.conversation_participants
    for insert with check (true);
exception when duplicate_object then null;
end $$;

-- messages: UPDATE (fuer markAsRead)
do $$ begin
  create policy "messages_update" on public.messages
    for update using (
      conversation_id in (
        select conversation_id from public.conversation_participants
        where user_id = auth.uid()
      )
    );
exception when duplicate_object then null;
end $$;
