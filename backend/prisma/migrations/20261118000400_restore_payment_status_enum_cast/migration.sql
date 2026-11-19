-- Repair the PaymentStatus enum cast while preserving stable guest replay.
CREATE OR REPLACE FUNCTION public.create_event_order(
  p_event_id UUID,
  p_items JSONB,
  p_attendees JSONB,
  p_guest_name TEXT,
  p_guest_email TEXT,
  p_guest_phone TEXT,
  p_purchaser_id UUID,
  p_order_number TEXT,
  p_idempotency_key TEXT,
  p_idempotency_fingerprint TEXT,
  p_guest_access_token_hash TEXT,
  p_expires_at TIMESTAMPTZ,
  p_virtual_account_number TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  event_row public.events%ROWTYPE;
  ticket_type_row public.ticket_types%ROWTYPE;
  item RECORD;
  order_id UUID;
  item_id UUID;
  attendee_id UUID;
  order_status public."OrderStatus";
  item_subtotal NUMERIC(14, 2);
  subtotal NUMERIC(14, 2) := 0;
  payment_id UUID;
  total_quantity INTEGER := 0;
  service_fee NUMERIC(14, 2);
  commission_amount NUMERIC(14, 2);
  grand_total NUMERIC(14, 2);
  quantity INTEGER;
  ticket_code TEXT;
  attendee_data JSONB;
  attendee_index INTEGER;
  expired_order RECORD;
  reserved_item RECORD;
BEGIN
  IF p_idempotency_key IS NULL
    OR length(p_idempotency_key) NOT BETWEEN 16 AND 200
    OR p_idempotency_fingerprint IS NULL
    OR p_idempotency_fingerprint !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'A valid idempotency key and fingerprint are required';
  END IF;
  IF p_purchaser_id IS NULL AND (
    p_guest_access_token_hash IS NULL OR
    NULLIF(pg_catalog.btrim(p_guest_name), '') IS NULL OR
    NULLIF(pg_catalog.btrim(p_guest_email), '') IS NULL
  ) THEN
    RAISE EXCEPTION 'Guest contact and access data are required';
  END IF;
  IF jsonb_typeof(p_items) <> 'object' OR p_items = '{}'::jsonb THEN
    RAISE EXCEPTION 'At least one ticket type is required';
  END IF;
  IF jsonb_typeof(p_attendees) <> 'object' THEN
    RAISE EXCEPTION 'Attendee data is required';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_idempotency_key, 0));
  SELECT id INTO order_id
  FROM public.event_orders
  WHERE idempotency_key = p_idempotency_key
    AND idempotency_fingerprint = p_idempotency_fingerprint;
  IF FOUND THEN
    -- Replay idempotency: JANGAN merotasi guest_access_token_hash. Token yang
    -- sudah diberikan pada response pertama harus tetap valid.
    IF p_purchaser_id IS NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.event_orders
        WHERE id = order_id AND purchaser_id IS NULL
      ) THEN
        RAISE EXCEPTION 'Idempotency key belongs to another order';
      END IF;
    ELSIF NOT EXISTS (
      SELECT 1 FROM public.event_orders
      WHERE id = order_id AND purchaser_id = p_purchaser_id
    ) THEN
      RAISE EXCEPTION 'Idempotency key belongs to another order';
    END IF;
    RETURN order_id;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.event_orders
    WHERE idempotency_key = p_idempotency_key
  ) THEN
    RAISE EXCEPTION 'Idempotency key was reused with different order data';
  END IF;

  SELECT * INTO event_row
  FROM public.events
  WHERE id = p_event_id
    AND is_public
    AND status IN ('APPROVED', 'PUBLISHED')
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event is not available for registration';
  END IF;

  FOR expired_order IN
    SELECT id
    FROM public.event_orders
    WHERE event_id = p_event_id
      AND status = 'PENDING_PAYMENT'
      AND expires_at <= pg_catalog.now()
    FOR UPDATE
  LOOP
    FOR reserved_item IN
      SELECT ticket_type_id, quantity
      FROM public.order_items
      WHERE order_id = expired_order.id
    LOOP
      UPDATE public.ticket_types
      SET held = GREATEST(0, held - reserved_item.quantity),
          updated_at = pg_catalog.now()
      WHERE id = reserved_item.ticket_type_id;
    END LOOP;
    UPDATE public.event_orders
    SET status = 'EXPIRED', updated_at = pg_catalog.now()
    WHERE id = expired_order.id;
    UPDATE public.order_payments
    SET status = 'EXPIRED', updated_at = pg_catalog.now()
    WHERE order_id = expired_order.id AND status = 'PENDING';
  END LOOP;

  FOR item IN
    SELECT key::UUID AS ticket_type_id, value AS raw_quantity
    FROM jsonb_each_text(p_items)
    ORDER BY key::UUID
  LOOP
    IF item.raw_quantity !~ '^[1-9][0-9]*$' THEN
      RAISE EXCEPTION 'Ticket quantities must be positive integers';
    END IF;
    quantity := item.raw_quantity::INTEGER;
    SELECT * INTO ticket_type_row
    FROM public.ticket_types
    WHERE id = item.ticket_type_id
      AND event_id = p_event_id
    FOR UPDATE;
    IF NOT FOUND OR NOT ticket_type_row.is_active THEN
      RAISE EXCEPTION 'Ticket type is unavailable';
    END IF;
    IF (ticket_type_row.sales_start IS NOT NULL AND ticket_type_row.sales_start > pg_catalog.now())
      OR (ticket_type_row.sales_end IS NOT NULL AND ticket_type_row.sales_end <= pg_catalog.now()) THEN
      RAISE EXCEPTION 'Ticket sales are outside the sales period';
    END IF;
    IF ticket_type_row.max_per_order IS NOT NULL AND quantity > ticket_type_row.max_per_order THEN
      RAISE EXCEPTION 'Ticket quantity exceeds the per-order limit';
    END IF;
    IF COALESCE(
      jsonb_typeof(p_attendees -> item.ticket_type_id::TEXT),
      ''
    ) <> 'array' THEN
      RAISE EXCEPTION 'Attendee count must match ticket quantity';
    END IF;
    IF jsonb_array_length(p_attendees -> item.ticket_type_id::TEXT) <> quantity THEN
      RAISE EXCEPTION 'Attendee count must match ticket quantity';
    END IF;
    IF ticket_type_row.sold + ticket_type_row.held + quantity > ticket_type_row.quota THEN
      RAISE EXCEPTION 'Ticket quota is insufficient';
    END IF;
    item_subtotal := pg_catalog.round(ticket_type_row.price * quantity, 2);
    subtotal := subtotal + item_subtotal;
    total_quantity := total_quantity + quantity;
  END LOOP;

  IF total_quantity = 0 THEN
    RAISE EXCEPTION 'At least one ticket is required';
  END IF;
  IF total_quantity > 20 THEN
    RAISE EXCEPTION 'An order cannot contain more than 20 tickets';
  END IF;

  service_fee := CASE WHEN subtotal > 0 THEN 5000 ELSE 0 END;
  commission_amount := pg_catalog.round(subtotal * 0.05, 2);
  grand_total := subtotal + service_fee;
  order_status := CASE
    WHEN grand_total = 0 THEN 'PAID'::public."OrderStatus"
    ELSE 'PENDING_PAYMENT'::public."OrderStatus"
  END;

  INSERT INTO public.event_orders (
    order_number, event_id, purchaser_id, guest_name, guest_email, guest_phone,
    guest_access_token_hash, idempotency_key, idempotency_fingerprint,
    status, subtotal, service_fee,
    commission_rate, commission_amount, grand_total, expires_at
  )
  VALUES (
    p_order_number, p_event_id, p_purchaser_id,
    NULLIF(pg_catalog.btrim(p_guest_name), ''),
    NULLIF(pg_catalog.btrim(p_guest_email), ''),
    NULLIF(pg_catalog.btrim(p_guest_phone), ''),
    CASE WHEN p_purchaser_id IS NULL THEN p_guest_access_token_hash END,
    p_idempotency_key, p_idempotency_fingerprint, order_status, subtotal, service_fee,
    0.05, commission_amount, grand_total,
    CASE WHEN grand_total = 0 THEN NULL ELSE p_expires_at END
  )
  RETURNING id INTO order_id;

  FOR item IN
    SELECT key::UUID AS ticket_type_id, value::INTEGER AS quantity
    FROM jsonb_each_text(p_items)
    ORDER BY key::UUID
  LOOP
    SELECT * INTO ticket_type_row
    FROM public.ticket_types
    WHERE id = item.ticket_type_id
      AND event_id = p_event_id;
    item_subtotal := pg_catalog.round(ticket_type_row.price * item.quantity, 2);
    INSERT INTO public.order_items (order_id, ticket_type_id, quantity, unit_price, subtotal)
    VALUES (order_id, item.ticket_type_id, item.quantity, ticket_type_row.price, item_subtotal)
    RETURNING id INTO item_id;

    IF grand_total > 0 THEN
      UPDATE public.ticket_types
      SET held = held + item.quantity, updated_at = pg_catalog.now()
      WHERE id = item.ticket_type_id;
    ELSE
      UPDATE public.ticket_types
      SET sold = sold + item.quantity, updated_at = pg_catalog.now()
      WHERE id = item.ticket_type_id;
    END IF;

    FOR attendee_index IN 1..item.quantity LOOP
      attendee_data := p_attendees -> item.ticket_type_id::TEXT -> (attendee_index - 1);
      IF NULLIF(pg_catalog.btrim(attendee_data ->> 'name'), '') IS NULL
        OR NULLIF(pg_catalog.btrim(attendee_data ->> 'email'), '') IS NULL THEN
        RAISE EXCEPTION 'Attendee name and email are required';
      END IF;
      INSERT INTO public.attendees (order_item_id, name, email, phone)
      VALUES (
        item_id,
        pg_catalog.btrim(attendee_data ->> 'name'),
        pg_catalog.btrim(attendee_data ->> 'email'),
        NULLIF(pg_catalog.btrim(attendee_data ->> 'phone'), '')
      )
      RETURNING id INTO attendee_id;

      IF grand_total = 0 THEN
        ticket_code := 'TKT-' || pg_catalog.replace(pg_catalog.gen_random_uuid()::TEXT, '-', '');
        INSERT INTO public.tickets (
          ticket_code, event_id, user_id, ticket_type_id, attendee_id,
          qr_code_data, status, purchased_at, issued_at
        )
        VALUES (
          ticket_code, p_event_id, p_purchaser_id, item.ticket_type_id, attendee_id,
          ticket_code, 'active', pg_catalog.now(), pg_catalog.now()
        );
      END IF;
    END LOOP;
  END LOOP;

  INSERT INTO public.order_payments (
    order_id, status, amount, virtual_account_number, virtual_account_bank,
    payment_reference, expires_at, paid_at
  )
  VALUES (
    order_id,
    (CASE WHEN grand_total = 0 THEN 'PAID' ELSE 'PENDING' END)::public."PaymentStatus",
    grand_total,
    CASE WHEN grand_total = 0 THEN NULL ELSE p_virtual_account_number END,
    CASE WHEN grand_total = 0 THEN NULL ELSE 'VA Simulasi' END,
    'SIM-' || p_order_number,
    CASE WHEN grand_total = 0 THEN NULL ELSE p_expires_at END,
    CASE WHEN grand_total = 0 THEN pg_catalog.now() END
  )
  RETURNING id INTO payment_id;

  IF grand_total = 0 THEN
    INSERT INTO public.platform_transactions (
      order_payment_id, gross_amount, commission_rate, commission_amount,
      service_fee, platform_revenue, organizer_net_amount
    )
    VALUES (
      payment_id, subtotal, 0.05, commission_amount, service_fee,
      commission_amount + service_fee, subtotal - commission_amount
    );
  END IF;

  RETURN order_id;
END;
$$;
