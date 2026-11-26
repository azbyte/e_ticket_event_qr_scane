-- Desain tiket (PRD §5): template/default dan upload custom per event maupun
-- per kategori tiket. Kolom JSONB aditif dan nullable sehingga data lama tetap
-- valid; null berarti sistem memakai desain default saat menerbitkan tiket.
ALTER TABLE "events" ADD COLUMN "ticket_design" JSONB;
ALTER TABLE "ticket_types" ADD COLUMN "ticket_design" JSONB;
