-- Orientasi tiket harus dapat "belum diatur" agar kategori tiket bisa
-- mewarisi orientasi dari level event (dan event mewarisi default sistem).
--
-- Sebelumnya kolom NOT NULL DEFAULT 'landscape' membuat kategori tanpa
-- pengaturan selalu dianggap "landscape eksplisit", sehingga orientasi portrait
-- pada level event tidak pernah dipakai saat mencetak tiket kategori tersebut.
--
-- Aturan baru:
--   NULL        -> belum diatur, mewarisi level di atasnya,
--   'landscape' -> horizontal (eksplisit),
--   'portrait'  -> vertikal (eksplisit).
--
-- Baris lama yang belum pernah menyimpan desain dianggap belum diatur; baris
-- yang sudah punya desain mempertahankan orientasinya.
ALTER TABLE "events" ALTER COLUMN "ticket_design_orientation" DROP DEFAULT;
ALTER TABLE "events" ALTER COLUMN "ticket_design_orientation" DROP NOT NULL;
ALTER TABLE "ticket_types" ALTER COLUMN "ticket_design_orientation" DROP DEFAULT;
ALTER TABLE "ticket_types" ALTER COLUMN "ticket_design_orientation" DROP NOT NULL;

UPDATE "events" SET "ticket_design_orientation" = NULL
 WHERE "ticket_design" IS NULL
   AND lower(COALESCE("ticket_design" ->> 'orientation', '')) <> 'portrait';

UPDATE "ticket_types" SET "ticket_design_orientation" = NULL
 WHERE "ticket_design" IS NULL
   AND lower(COALESCE("ticket_design" ->> 'orientation', '')) <> 'portrait';
