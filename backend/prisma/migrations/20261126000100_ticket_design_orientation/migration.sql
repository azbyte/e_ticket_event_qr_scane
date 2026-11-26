-- Orientasi desain tiket (landscape / portrait).
--
-- Nilai disimpan sebagai kolom sendiri (bukan hanya di dalam JSONB) agar:
--  1. konfigurasi orientasi tetap ada walau Organizer belum mengunggah desain,
--  2. CHECK constraint database menjamin hanya nilai sah yang tersimpan,
--  3. tiket yang dirender selalu dapat membaca orientasi yang dipilih.
--
-- Default `landscape` menjaga perilaku data lama (kanvas horizontal 720x288).
-- Aturan bisnis lama (desain kategori menimpa desain event) tidak berubah:
-- orientasi tiket mengikuti desain yang menang, lalu orientasi event, lalu
-- default sistem.
ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "ticket_design_orientation" TEXT NOT NULL DEFAULT 'landscape';

ALTER TABLE "ticket_types"
  ADD COLUMN IF NOT EXISTS "ticket_design_orientation" TEXT NOT NULL DEFAULT 'landscape';

UPDATE "events"
   SET "ticket_design_orientation" = 'portrait'
 WHERE lower(COALESCE("ticket_design" ->> 'orientation', '')) = 'portrait';

UPDATE "ticket_types"
   SET "ticket_design_orientation" = 'portrait'
 WHERE lower(COALESCE("ticket_design" ->> 'orientation', '')) = 'portrait';

ALTER TABLE "events"
  DROP CONSTRAINT IF EXISTS "events_ticket_design_orientation_check";
ALTER TABLE "events"
  ADD CONSTRAINT "events_ticket_design_orientation_check"
  CHECK ("ticket_design_orientation" IN ('landscape', 'portrait'));

ALTER TABLE "ticket_types"
  DROP CONSTRAINT IF EXISTS "ticket_types_ticket_design_orientation_check";
ALTER TABLE "ticket_types"
  ADD CONSTRAINT "ticket_types_ticket_design_orientation_check"
  CHECK ("ticket_design_orientation" IN ('landscape', 'portrait'));
