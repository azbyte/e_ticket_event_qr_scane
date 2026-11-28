-- Undangan staf berbasis NAMA + KODE AKSES (PRD §6.2 revisi).
--
-- Perubahan bersifat aditif & nullable sehingga data undangan lama (email-based)
-- tetap valid:
--   * `staff_name`            : nama staf yang diundang (mekanisme baru),
--   * `access_code_hash`      : SHA-256 kode akses (untuk verifikasi; TIDAK
--                               plaintext) + indeks unik GLOBAL,
--   * `access_code_cipher`    : ciphertext AES-256-GCM agar Organizer dapat
--                               menampilkan kembali kode milik event-nya,
--   * `access_code_issued_at` : waktu kode diterbitkan/diperbarui,
--   * `email`                 : boleh NULL karena undangan baru tidak memakai
--                               email (staf tidak wajib punya akun).
--
-- Keunikan kode akses dijaga database (bukan hanya pengecekan aplikasi), baik
-- antar undangan pada event yang sama maupun lintas event.

ALTER TABLE "event_invitations" ALTER COLUMN "email" DROP NOT NULL;

ALTER TABLE "event_invitations" ADD COLUMN IF NOT EXISTS "staff_name" TEXT;
ALTER TABLE "event_invitations" ADD COLUMN IF NOT EXISTS "access_code_hash" TEXT;
ALTER TABLE "event_invitations" ADD COLUMN IF NOT EXISTS "access_code_cipher" TEXT;
ALTER TABLE "event_invitations" ADD COLUMN IF NOT EXISTS "access_code_issued_at" TIMESTAMPTZ(6);

-- Indeks unik global. PostgreSQL mengizinkan banyak NULL pada indeks unik,
-- sehingga undangan lama tanpa kode akses tidak bertabrakan.
CREATE UNIQUE INDEX IF NOT EXISTS "event_invitations_access_code_hash_key"
  ON "event_invitations"("access_code_hash");

CREATE INDEX IF NOT EXISTS "event_invitations_event_id_staff_name_idx"
  ON "event_invitations"("event_id", "staff_name");

-- Undangan email lama yang masih PENDING tetap tersimpan. Agar dapat dipakai
-- pada mekanisme kode akses, Organizer menekan "Buat kode baru" pada halaman
-- pengelolaan staf (endpoint regenerate); tidak ada kode yang dibuat otomatis
-- di sini karena plaintext-nya tidak dapat ditampilkan setelah migrasi.

-- ---------------------------------------------------------------------------
-- Jejak audit check-in untuk staf undangan (tanpa akun profiles).
--
-- `check_ins.actor_user_id` sebelumnya NOT NULL + FK ke `profiles`, sehingga
-- staf yang masuk lewat kode akses tidak dapat dicatat. Kolom itu dibuat
-- nullable dan ditambah `staff_invitation_id` sebagai identitas pelaku.
-- ---------------------------------------------------------------------------

ALTER TABLE "check_ins" ALTER COLUMN "actor_user_id" DROP NOT NULL;
ALTER TABLE "check_ins" ADD COLUMN IF NOT EXISTS "staff_invitation_id" UUID;
ALTER TABLE "scan_logs" ADD COLUMN IF NOT EXISTS "staff_invitation_id" UUID;

ALTER TABLE "check_ins"
  ADD CONSTRAINT "check_ins_staff_invitation_id_fkey"
  FOREIGN KEY ("staff_invitation_id") REFERENCES "event_invitations"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "scan_logs"
  ADD CONSTRAINT "scan_logs_staff_invitation_id_fkey"
  FOREIGN KEY ("staff_invitation_id") REFERENCES "event_invitations"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX IF NOT EXISTS "check_ins_staff_invitation_id_idx"
  ON "check_ins"("staff_invitation_id");
CREATE INDEX IF NOT EXISTS "scan_logs_staff_invitation_id_idx"
  ON "scan_logs"("staff_invitation_id");
