ALTER TABLE public.events
ADD COLUMN poster_url TEXT;

INSERT INTO public.event_categories (name, slug)
VALUES
  ('Musik', 'musik'),
  ('Seminar', 'seminar'),
  ('Workshop', 'workshop'),
  ('Olahraga', 'olahraga'),
  ('Pameran', 'pameran'),
  ('Komunitas', 'komunitas'),
  ('Lainnya', 'lainnya'),
  ('Teknologi', 'teknologi')
ON CONFLICT DO NOTHING;
