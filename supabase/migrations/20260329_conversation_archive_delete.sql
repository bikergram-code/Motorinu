-- RPC functions for archiving and deleting conversations.
-- These use SECURITY DEFINER to bypass RLS on conversation_participants,
-- while still checking that the caller owns the participant row.

-- Archive: set archived_at on the caller's participant row
CREATE OR REPLACE FUNCTION archive_conversation(conv_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversation_participants
     SET archived_at = now()
   WHERE conversation_id = conv_id
     AND user_id = auth.uid();
END;
$$;

-- Unarchive: clear archived_at on the caller's participant row
CREATE OR REPLACE FUNCTION unarchive_conversation(conv_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversation_participants
     SET archived_at = NULL
   WHERE conversation_id = conv_id
     AND user_id = auth.uid();
END;
$$;

-- Leave / delete: remove the caller's participant row.
-- If no participants remain, clean up messages and conversation.
CREATE OR REPLACE FUNCTION leave_conversation(conv_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  remaining int;
BEGIN
  DELETE FROM conversation_participants
   WHERE conversation_id = conv_id
     AND user_id = auth.uid();

  SELECT count(*) INTO remaining
    FROM conversation_participants
   WHERE conversation_id = conv_id;

  IF remaining = 0 THEN
    DELETE FROM messages WHERE conversation_id = conv_id;
    DELETE FROM conversations WHERE id = conv_id;
  END IF;
END;
$$;
