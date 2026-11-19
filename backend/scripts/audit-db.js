/**
 * Audit database read-only.
 *
 * Membandingkan struktur database PostgreSQL yang sedang terhubung dengan
 * schema Prisma, lalu mencetak ringkasan tabel, kolom, constraint, index,
 * enum, function, dan status migrasi. Skrip ini tidak menulis/mengubah data.
 *
 * Jalankan dari folder backend: `node scripts/audit-db.js`
 */
const path = require('node:path');
const fs = require('node:fs');
const { Pool } = require('pg');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const schemaPath = path.resolve(__dirname, '..', 'prisma', 'schema.prisma');

const readPrismaModels = () => {
  const source = fs.readFileSync(schemaPath, 'utf8');
  const models = [];
  const modelPattern = /^model\s+(\w+)\s*\{([\s\S]*?)^\}/gm;
  let match;
  while ((match = modelPattern.exec(source)) !== null) {
    const body = match[2];
    const mapMatch = body.match(/@@map\("([^"]+)"\)/);
    const table = mapMatch ? mapMatch[1] : match[1];
    models.push({ model: match[1], table });
  }
  return models;
};

const readPrismaEnums = () => {
  const source = fs.readFileSync(schemaPath, 'utf8');
  const enums = [];
  const enumPattern = /^enum\s+(\w+)\s*\{([\s\S]*?)^\}/gm;
  let match;
  while ((match = enumPattern.exec(source)) !== null) {
    const values = match[2]
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('//'));
    enums.push({ name: match[1], values });
  }
  return enums;
};

const main = async () => {
  if (!process.env.DATABASE_URL) {
    console.error('❌ DATABASE_URL not configured.');
    console.error('   Set DATABASE_URL environment variable to enable database audit.');
    console.error('   Example: export DATABASE_URL=postgresql://user:pass@host:port/db');
    process.exitCode = 1;
    return;
  }

  const models = readPrismaModels();
  const prismaEnums = readPrismaEnums();
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    connectionTimeoutMillis: 15000,
  });
  const client = await pool.connect();

  try {
    const tables = await client.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
       ORDER BY table_name`
    );
    const tableNames = tables.rows.map((row) => row.table_name);
    const applicationTables = tableNames.filter((table) => table !== '_prisma_migrations');
    const expectedTables = models.map((model) => model.table).sort();
    const missing = expectedTables.filter((table) => !applicationTables.includes(table));
    const unexpected = applicationTables.filter((table) => !expectedTables.includes(table));

    console.log('=== RINGKASAN DATABASE ===');
    console.log(`Tabel public: ${tableNames.length} (aplikasi: ${applicationTables.length}, internal Prisma: ${tableNames.length - applicationTables.length})`);
    console.log(`Model Prisma: ${models.length}`);
    console.log(`Tabel hilang dari database: ${missing.length ? missing.join(', ') : 'tidak ada'}`);
    console.log(`Tabel di luar schema: ${unexpected.length ? unexpected.join(', ') : 'tidak ada'}`);

    const columns = await client.query(
      `SELECT table_name, column_name, data_type, udt_name, is_nullable,
              column_default, character_maximum_length, numeric_precision, numeric_scale
       FROM information_schema.columns
       WHERE table_schema = 'public'
       ORDER BY table_name, ordinal_position`
    );
    const byTable = new Map();
    for (const column of columns.rows) {
      if (!byTable.has(column.table_name)) byTable.set(column.table_name, []);
      byTable.get(column.table_name).push(column);
    }
    console.log('\n=== KOLOM PER TABEL ===');
    for (const table of tableNames) {
      const list = byTable.get(table) || [];
      const detail = list.map((column) => {
        const type = column.data_type === 'USER-DEFINED' ? column.udt_name : column.data_type;
        const nullable = column.is_nullable === 'YES' ? 'NULL' : 'NOT NULL';
        const defaultValue = column.column_default ? ` DEFAULT ${column.column_default}` : '';
        return `${column.column_name}:${type} ${nullable}${defaultValue}`;
      });
      console.log(`- ${table} (${list.length} kolom): ${detail.join('; ')}`);
    }

    const constraints = await client.query(
      `SELECT c.conname, c.contype, t.relname AS table_name,
              pg_get_constraintdef(c.oid) AS definition
       FROM pg_constraint c
       JOIN pg_class t ON t.oid = c.conrelid
       JOIN pg_namespace n ON n.oid = t.relnamespace
       WHERE n.nspname = 'public'
       ORDER BY t.relname, c.contype, c.conname`
    );
    const counts = constraints.rows.reduce((acc, row) => {
      acc[row.contype] = (acc[row.contype] || 0) + 1;
      return acc;
    }, {});
    console.log('\n=== CONSTRAINT ===');
    console.log(
      `primary=${counts.p || 0}, foreign=${counts.f || 0}, unique=${counts.u || 0}, check=${counts.c || 0}, exclusion=${counts.x || 0}`
    );
    for (const row of constraints.rows) {
      console.log(`- ${row.table_name} [${row.contype}] ${row.conname}: ${row.definition}`);
    }


    const indexes = await client.query(
      `SELECT tablename, indexname, indexdef FROM pg_indexes
       WHERE schemaname = 'public' ORDER BY tablename, indexname`
    );
    console.log('\n=== INDEX ===');
    console.log(`Total index public: ${indexes.rows.length}`);
    for (const row of indexes.rows) {
      console.log(`- ${row.tablename}: ${row.indexname}`);
    }

    const enums = await client.query(
      `SELECT t.typname AS name, e.enumlabel AS value, e.enumsortorder
       FROM pg_type t
       JOIN pg_enum e ON e.enumtypid = t.oid
       JOIN pg_namespace n ON n.oid = t.typnamespace
       WHERE n.nspname = 'public'
       ORDER BY t.typname, e.enumsortorder`
    );
    const enumMap = new Map();
    for (const row of enums.rows) {
      if (!enumMap.has(row.name)) enumMap.set(row.name, []);
      enumMap.get(row.name).push(row.value);
    }
    console.log('\n=== ENUM ===');
    console.log(`Enum Prisma: ${prismaEnums.length}; enum database: ${enumMap.size}`);
    for (const [name, values] of enumMap.entries()) {
      const expected = prismaEnums.find((item) => item.name === name);
      const same = expected && expected.values.join(',') === values.join(',');
      console.log(`- ${name} (${same ? 'sesuai' : 'PERIKSA'}): ${values.join(', ')}`);
    }
    const missingEnums = prismaEnums
      .map((item) => item.name)
      .filter((name) => !enumMap.has(name));
    console.log(`Enum hilang: ${missingEnums.length ? missingEnums.join(', ') : 'tidak ada'}`);

    const functions = await client.query(
      `SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' ORDER BY p.proname`
    );
    console.log('\n=== FUNCTION PUBLIC ===');
    console.log(functions.rows.length
      ? functions.rows.map((row) => `- ${row.proname}(${row.args})`).join('\n')
      : '(tidak ada)');

    const rls = await client.query(
      `SELECT c.relname, c.relrowsecurity
       FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' ORDER BY c.relname`
    );
    const rlsEnabled = rls.rows.filter((row) => row.relrowsecurity).length;
    console.log('\n=== ROW LEVEL SECURITY ===');
    console.log(`${rlsEnabled}/${rls.rows.length} tabel mengaktifkan RLS`);
    const policies = await client.query(
      `SELECT schemaname, tablename, policyname FROM pg_policies
       WHERE schemaname = 'public' ORDER BY tablename, policyname`
    );
    console.log(`Policy RLS: ${policies.rows.length}`);
    policies.rows.forEach((row) => console.log(`- ${row.tablename}: ${row.policyname}`));

    const grants = await client.query(
      `SELECT grantee, COUNT(*)::int AS total
       FROM information_schema.role_table_grants
       WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated')
       GROUP BY grantee ORDER BY grantee`
    );
    console.log('Grant tabel ke role Supabase:');
    console.log(grants.rows.length
      ? grants.rows.map((row) => `- ${row.grantee}: ${row.total} grant`).join('\n')
      : '- tidak ada grant untuk anon/authenticated');
    if (rlsEnabled === 0 && grants.rows.length > 0) {
      console.log('PERINGATAN: RLS mati + grant anon/authenticated aktif = data dapat');
      console.log('diakses lewat Supabase REST menggunakan anon key. Wajib ditutup sebelum rilis.');
    }

    const migrationTable = await client.query(
      `SELECT to_regclass('public._prisma_migrations') AS table`
    );
    console.log('\n=== PRISMA MIGRATION HISTORY ===');
    if (migrationTable.rows[0].table) {
      const applied = await client.query(
        `SELECT migration_name, finished_at, rolled_back_at
         FROM public._prisma_migrations ORDER BY started_at`
      );
      console.log(applied.rows.length ? applied.rows.map((row) =>
        `- ${row.migration_name} finished=${row.finished_at || 'null'} rolledBack=${row.rolled_back_at || 'null'}`
      ).join('\n') : '(kosong)');
    } else {
      console.log('Tabel _prisma_migrations tidak ada (migrasi belum pernah dicatat Prisma).');
    }

    console.log('\n=== JUMLAH BARIS TABEL UTAMA ===');
    for (const table of ['profiles', 'events', 'ticket_types', 'event_orders', 'tickets', 'check_ins', 'support_reports', 'notifications']) {
      if (!tableNames.includes(table)) continue;
      const result = await client.query(`SELECT COUNT(*)::bigint AS count FROM public."${table}"`);
      console.log(`- ${table}: ${result.rows[0].count}`);
    }
  } finally {
    client.release();
    await pool.end();
  }
};

main().catch((error) => {
  console.error('Audit database gagal:', error.message);
  process.exitCode = 1;
});
