ALTER TABLE public.ticket_types
DROP CONSTRAINT ticket_types_event_id_fkey;

ALTER TABLE public.ticket_types
ADD CONSTRAINT ticket_types_event_id_fkey
FOREIGN KEY (event_id)
REFERENCES public.events(id)
ON DELETE CASCADE
ON UPDATE CASCADE;
