CREATE OR REPLACE FUNCTION public.moderate_event(
  p_event_id UUID,
  p_admin_id UUID,
  p_admin_name TEXT,
  p_decision TEXT,
  p_note TEXT
)
RETURNS SETOF public.events
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  current_status public."EventStatus";
BEGIN
  SELECT status
  INTO current_status
  FROM public.events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event not found';
  END IF;

  IF p_decision NOT IN ('APPROVED', 'REVISION_REQUESTED', 'REJECTED', 'SUSPENDED') THEN
    RAISE EXCEPTION 'Invalid moderation decision';
  END IF;

  IF p_decision <> 'APPROVED' AND NULLIF(BTRIM(p_note), '') IS NULL THEN
    RAISE EXCEPTION 'A moderation note is required';
  END IF;

  IF p_decision = 'SUSPENDED' THEN
    IF current_status NOT IN ('APPROVED', 'PUBLISHED') THEN
      RAISE EXCEPTION 'Only approved events can be suspended';
    END IF;
  ELSIF current_status NOT IN ('PENDING_REVIEW', 'REVISION_REQUESTED')
      AND NOT (p_decision = 'APPROVED' AND current_status = 'SUSPENDED') THEN
    RAISE EXCEPTION 'Event is not eligible for moderation';
  END IF;

  UPDATE public.events
  SET status = p_decision::public."EventStatus",
      review_note = CASE WHEN p_decision = 'APPROVED' THEN NULL ELSE BTRIM(p_note) END,
      is_public = p_decision = 'APPROVED',
      public_url = CASE
        WHEN p_decision IN ('APPROVED', 'SUSPENDED') THEN public_url
        ELSE NULL
      END,
      registration_qr_url = CASE
        WHEN p_decision IN ('APPROVED', 'SUSPENDED') THEN registration_qr_url
        ELSE NULL
      END,
      updated_at = pg_catalog.now()
  WHERE id = p_event_id;

  INSERT INTO public.event_moderations (event_id, admin_id, decision, note)
  VALUES (
    p_event_id,
    p_admin_id,
    p_decision::public."ModerationDecision",
    NULLIF(BTRIM(p_note), '')
  );

  INSERT INTO public.audit_logs (
    actor_id,
    actor_name,
    actor_role,
    action,
    entity_type,
    entity_id,
    reason,
    details,
    metadata
  )
  VALUES (
    p_admin_id,
    p_admin_name,
    'admin',
    'EVENT_MODERATION_' || p_decision,
    'EVENT',
    p_event_id::TEXT,
    NULLIF(BTRIM(p_note), ''),
    'Admin updated event moderation status',
    pg_catalog.jsonb_build_object('decision', p_decision)
  );

  RETURN QUERY SELECT * FROM public.events WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_event(UUID, UUID, TEXT, TEXT, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_event(UUID, UUID, TEXT, TEXT, TEXT)
TO service_role;
