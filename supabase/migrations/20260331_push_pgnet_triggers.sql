-- Push-Notification Trigger via pg_net
-- Sends HTTP POST to VPS push-service on notification/message INSERT

-- Ensure pg_net extension is available
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ============================================================
-- Trigger function: notifications table → push-service
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_push_notification()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url := 'http://152.53.255.4/webhook/notification',
    headers := '{"Content-Type":"application/json","X-Webhook-Secret":"aGv-lQT8heozSbcZ5RHf5eUuWxQqE4-QofeH8FPPxto"}'::jsonb,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'record', row_to_json(NEW)::jsonb
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Trigger function: messages table → push-service
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_push_message()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url := 'http://152.53.255.4/webhook/message',
    headers := '{"Content-Type":"application/json","X-Webhook-Secret":"aGv-lQT8heozSbcZ5RHf5eUuWxQqE4-QofeH8FPPxto"}'::jsonb,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'messages',
      'record', row_to_json(NEW)::jsonb
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Create triggers (replace existing if any)
-- ============================================================
DROP TRIGGER IF EXISTS trg_push_notification ON public.notifications;
CREATE TRIGGER trg_push_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_notification();

DROP TRIGGER IF EXISTS trg_push_message ON public.messages;
CREATE TRIGGER trg_push_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_message();
