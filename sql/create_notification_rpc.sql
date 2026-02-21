-- ============================================================
-- BIKERGRAM: Notification System Setup
-- Run this ENTIRE script in the Supabase SQL Editor.
-- ============================================================

-- 1) RPC: create_notification
-- Allows authenticated users to create notifications for OTHER users.
-- Uses SECURITY DEFINER to bypass RLS.
-- ============================================================

create or replace function public.create_notification(
  p_target_user_id uuid,
  p_type text,
  p_title text,
  p_body text default null,
  p_data jsonb default '{}'
)
returns void as $$
begin
  -- Don't create self-notifications
  if p_target_user_id = auth.uid() then
    return;
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (p_target_user_id, p_type, p_title, p_body, p_data);
end;
$$ language plpgsql security definer;

-- 2) INSERT Policy: Allow authenticated users to insert notifications
-- for OTHER users (fallback if RPC doesn't work).
-- ============================================================

DO $$
BEGIN
  -- Drop existing insert policy if it exists
  BEGIN
    DROP POLICY IF EXISTS "Users can create notifications for others" ON public.notifications;
  EXCEPTION WHEN undefined_object THEN
    NULL;
  END;
END $$;

CREATE POLICY "Users can create notifications for others"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id != auth.uid());

-- 3) Add tables to Realtime publication (ignore errors if already added)
-- ============================================================

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;
