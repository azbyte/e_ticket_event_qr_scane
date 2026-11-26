# Legacy SQL (bukan bagian riwayat migration Prisma)

Folder ini menyimpan SQL warisan yang **tidak** dijalankan oleh Prisma dan
**tidak** tercatat di tabel `_prisma_migrations`.

| Aspek | Nilai |
|---|---|
| Status | **Beku** — jangan dijalankan, jangan dipindahkan ke `../migrations/` |
| Dijalankan `prisma migrate deploy` | **Tidak** (Prisma hanya membaca `../migrations/`) |
| Tercatat di `_prisma_migrations` | Tidak |
| Otoritas perubahan | Penanggung jawab FINISHING (`../../../task/FINISHING_AUTHORITY.md`) |

## Mengapa tidak diletakkan di `../migrations/`

`prisma migrate` memperlakukan **setiap folder** di dalam `../migrations/`
sebagai satu migration. Diverifikasi pada Prisma 6.19 (26 November 2026) dengan
salinan skema terpisah:

- folder `migrations/legacy/` → `10 migrations found` + `Following migration have
  not yet been applied: legacy` → `prisma migrate status` gagal (exit 1) dan
  `migrate deploy` akan mencoba menjalankannya;
- file `.sql` lepas di `migrations/` → diabaikan, `9 migrations found`,
  `Database schema is up to date!`.

Karena SQL ini **tidak boleh** dijalankan otomatis, penempatannya di luar
`../migrations/` adalah syarat, bukan pilihan gaya.

## Isi `202611040001_role_access_and_event_members.sql`

File ini ditulis untuk dijalankan manual pada Supabase SQL Editor (gaya
idempotent `if not exists` / `drop policy if exists`). Hampir seluruh objeknya
sudah dibuat oleh migration Prisma dan **tidak** pernah diterapkan ke database
saat ini (bukti: `pg_policies` berisi 0 policy, sedangkan file ini membuat 5
policy `"server managed ..."`).

| Objek di file legacy | Cakupan di Prisma |
|---|---|
| `profiles.username`, `profiles.disabled_at`, `password_hash` nullable | `20261113000000_initial_application_schema` |
| `revoked_tokens` + `revoked_tokens_expires_at_idx` | `20261113000000_initial_application_schema` |
| `event_members` + `event_members_user_id_idx` | `20261113000000_initial_application_schema` |
| `events_created_by_idx` | `20261113000000_initial_application_schema` |
| RLS + cabut grant `anon`/`authenticated` | `20261118000200_rls_and_supabase_grants` (deny-by-default, lebih ketat: 0 policy + `ALTER DEFAULT PRIVILEGES`) |
| **`profiles_username_lower_unique`** (`lower(username) WHERE username IS NOT NULL`) | **BELUM ADA** — celah terbuka |

## Satu-satunya objek yang belum tercakup

Unique index case-insensitive pada `username`. Saat ini index tersebut tidak ada
di `schema.prisma`, tidak ada di 9 migration Prisma, dan tidak ada di database,
sehingga username hanya unik secara case-sensitive (`Admin` dan `admin` dapat
berdampingan). Penutupannya menunggu keputusan FINISHING — lihat **DP-05** pada
`../../../task/DB_CHANGE_PROPOSAL.md`. Jangan menambahkan index ini secara manual ke
database tanpa migration Prisma, karena akan menimbulkan drift.
