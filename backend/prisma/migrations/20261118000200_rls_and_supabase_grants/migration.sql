-- =============================================================================
-- Security hardening: Row Level Security + pencabutan akses klien.
--
-- Arsitektur akses proyek ini:
--   Flutter -> REST API Express -> PostgreSQL (role `postgres`, pemilik tabel)
-- Supabase PostgREST (role `anon`/`authenticated`) TIDAK dipakai aplikasi.
-- Karena itu kebijakan yang benar adalah *deny-by-default*: RLS diaktifkan pada
-- seluruh tabel aplikasi dan seluruh privilege dicabut dari `anon`/
-- `authenticated`. Tidak ada policy yang dibuat, sehingga kedua role tersebut
-- tidak dapat membaca maupun memodifikasi satu baris pun.
--
-- Otorisasi per pengguna (peserta/organizer/staff/admin), kepemilikan data, dan
-- relasi event ditegakkan oleh controller Express (lihat
-- backend/test/integration/security.test.js). Backend terhubung sebagai pemilik
-- tabel sehingga melewati RLS; itu memang disengaja dan bukan pengganti
-- otorisasi aplikasi.
--
-- ROLLBACK (jalankan manual bila perlu kembali ke kondisi lama):
--   ALTER TABLE public.<tabel> DISABLE ROW LEVEL SECURITY;
--   GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
--   GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
-- =============================================================================

-- 1) Aktifkan RLS pada seluruh tabel aplikasi (deny-by-default).
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> '_prisma_migrations'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', table_record.tablename);
  END LOOP;
END
$$;

-- 2) Cabut seluruh akses langsung dari role klien Supabase.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;

-- 3) Objek baru yang dibuat setelah migration ini juga tidak boleh otomatis
--    terbuka untuk role klien.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- 4) Function bisnis hanya boleh dieksekusi backend tepercaya.
--    (SECURITY INVOKER + search_path terkunci; lihat migration 002 dan 004.)
GRANT EXECUTE ON FUNCTION public.moderate_event(UUID, UUID, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_event_order_reservations(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_event_order(
  UUID, JSONB, JSONB, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT
) TO service_role;
GRANT EXECUTE ON FUNCTION public.simulate_event_payment(UUID, UUID, TEXT, BOOLEAN) TO service_role;
