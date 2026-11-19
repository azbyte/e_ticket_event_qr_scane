#!/usr/bin/env node
/**
 * Verifikasi sinkronisasi schema Prisma dengan database aktual (READ-ONLY).
 *
 * Metode berlapis:
 *  1. `prisma db pull` mengintrospeksi database ke datamodel sementara.
 *  2. `prisma migrate diff` dua arah: introspeksi <-> prisma/schema.prisma.
 *  3. Perbandingan silang jumlah model/PK/unique/index dengan pg_catalog.
 *  4. Inventaris objek di luar datamodel Prisma (function, trigger, RLS, grant).
 *
 * Tidak ada DDL/DML. Jalankan: node scripts/verify-schema-sync.js
 */
﻿/**
 * Verifikasi sinkronisasi schema Prisma dengan database aktual (READ-ONLY).
 *
 * Metode berlapis:
 *  1. `prisma db pull` mengintrospeksi database ke datamodel sementara.
 *  2. `prisma migrate diff` dua arah: introspeksi <-> prisma/schema.prisma.
 *  3. Perbandingan silang jumlah model/PK/unique/index dengan pg_catalog.
 *  4. Inventaris objek di luar datamodel Prisma (function, trigger, RLS, grant).
 *
 * Tidak ada DDL/DML. Jalankan: node scripts/verify-schema-sync.js
 */
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { Pool } = require('pg');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const backendRoot = path.resolve(__dirname, '..');
const committedSchema = path.join(backendRoot, 'prisma', 'schema.prisma');
const INTERNAL_TABLE = '_prisma_migrations';

const run = (command) => spawnSync(command, {
  cwd: backendRoot,
  encoding: 'utf8',
  shell: true,
});

const stripInternalModel = (text) => text.replace(
  new RegExp('model\\s+' + INTERNAL_TABLE + '\\s*\\{[\\s\\S]*?\\n\\}', 'g'),
  ''
);

const countDeclarations = (text) => ({
  fieldUnique: (text.match(/(^|[^@])@unique\b/gm) || []).length,
  modelUnique: (text.match(/@@unique\(/g) || []).length,
  modelIndex: (text.match(/@@index\(/g) || []).length,
  models: (text.match(/^model\s+\w+/gm) || []).length,
});



const main = async () => {
  if (!process.env.DATABASE_URL) {
    console.error('❌ DATABASE_URL not configured.');
    console.error('   Set DATABASE_URL environment variable to enable database verification.');
    console.error('   Example: export DATABASE_URL=postgresql://user:pass@host:port/db');
    process.exitCode = 1;
    return;
  }

  const failures = [];
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'eticket-schema-'));
  const tmpSchema = path.join(tmpDir, 'introspected.prisma');
  fs.writeFileSync(
    tmpSchema,
    'datasource db {\n  provider  = "postgresql"\n  url       = env("DATABASE_URL")\n  directUrl = env("DIRECT_URL")\n}\n',
    'utf8'
  );

  const pull = run('npx prisma db pull --schema "' + tmpSchema + '"');
  const pullOutput = (pull.stdout || '') + (pull.stderr || '');
  const pulled = fs.existsSync(tmpSchema) ? fs.readFileSync(tmpSchema, 'utf8') : '';
  if (pull.status !== 0 || !/model\s+\w+\s*\{/.test(pulled)) {
    console.error('GAGAL: prisma db pull tidak menghasilkan model.');
    console.error(pullOutput.split('\n').slice(-20).join('\n'));
    process.exitCode = 1;
    return;
  }
  fs.writeFileSync(tmpSchema, stripInternalModel(pulled), 'utf8');

  console.log('=== 1. INTROSPEKSI ULANG DATABASE (prisma db pull) ===');
  const introspected = fs.readFileSync(tmpSchema, 'utf8');
  const introspectedCounts = countDeclarations(introspected);
  console.log('Model terdeteksi di database: ' + introspectedCounts.models);
  console.log('Unique field: ' + introspectedCounts.fieldUnique +
    ', unique model: ' + introspectedCounts.modelUnique +
    ', index model: ' + introspectedCounts.modelIndex);

  console.log('\n=== 2. DIFF DUA ARAH ===');
  const directions = [
    ['database -> schema.prisma', tmpSchema, committedSchema],
    ['schema.prisma -> database', committedSchema, tmpSchema],
  ];
  for (const pair of directions) {
    const label = pair[0];
    const result = run('npx prisma migrate diff --from-schema-datamodel "' + pair[1] +
      '" --to-schema-datamodel "' + pair[2] + '" --script');
    const output = (result.stdout || '') + (result.stderr || '');
    const isEmpty = result.status === 0 && output.indexOf('-- This is an empty migration.') !== -1;
    console.log('- ' + label + ': ' + (isEmpty ? 'SAMA (empty migration)' : 'ADA PERBEDAAN'));
    if (!isEmpty) {
      failures.push('Diff ' + label + ' tidak kosong');
      console.log(output.split('\n').slice(0, 40).join('\n'));
    }
  }
  console.log('\n=== 3. PERBANDINGAN SILANG JUMLAH OBJEK ===');
  const committedText = fs.readFileSync(committedSchema, 'utf8');
  const committedCounts = countDeclarations(committedText);
  console.log('schema.prisma  -> model: ' + committedCounts.models +
    ', unique field: ' + committedCounts.fieldUnique +
    ', unique model: ' + committedCounts.modelUnique +
    ', index: ' + committedCounts.modelIndex);

  const compareCount = (label, expected, actual) => {
    if (expected !== actual) {
      failures.push(label + ': schema ' + expected + ' vs database ' + actual);
      console.log('- ' + label + ': BEDA (schema ' + expected + ', database ' + actual + ')');
    } else {
      console.log('- ' + label + ': SAMA (' + expected + ')');
    }
  };
  compareCount('Model = tabel aplikasi', committedCounts.models, introspectedCounts.models);
  compareCount('Unique constraint',
    committedCounts.fieldUnique + committedCounts.modelUnique,
    introspectedCounts.fieldUnique + introspectedCounts.modelUnique);
  compareCount('Index non-unique', committedCounts.modelIndex, introspectedCounts.modelIndex);

  const pool = new Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const tables = await client.query(
      'SELECT table_name FROM information_schema.tables ' +
      "WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name"
    );
    const appTables = [];
    for (const row of tables.rows) {
      if (row.table_name !== INTERNAL_TABLE) appTables.push(row.table_name);
    }
    compareCount('Jumlah tabel aplikasi', committedCounts.models, appTables.length);
    console.log('Tabel aplikasi: ' + appTables.join(', '));

    const keys = await client.query(
      'SELECT i.indisprimary, i.indisunique, count(*)::int AS total ' +
      'FROM pg_index i ' +
      'JOIN pg_class c ON c.oid = i.indexrelid ' +
      'JOIN pg_namespace n ON n.oid = c.relnamespace ' +
      "WHERE n.nspname = 'public' AND c.relname <> '" + INTERNAL_TABLE + "_pkey' " +
      'GROUP BY i.indisprimary, i.indisunique'
    );
    const byKind = (primary, unique) => {
      for (const row of keys.rows) {
        if (row.indisprimary === primary && row.indisunique === unique) return row.total;
      }
      return 0;
    };
    compareCount('Primary key', committedCounts.models, byKind(true, true));
    compareCount('Unique index (bukan PK)',
      committedCounts.fieldUnique + committedCounts.modelUnique, byKind(false, true));
    compareCount('Index non-unique', committedCounts.modelIndex, byKind(false, false));
    const partial = await client.query(
      'SELECT tablename, indexname, indexdef FROM pg_indexes ' +
      "WHERE schemaname = 'public' AND indexdef ~ ' WHERE '"
    );
    console.log('\nIndex parsial (di luar Prisma): ' + partial.rows.length);
    for (const row of partial.rows) console.log('- ' + row.tablename + '.' + row.indexname + ': ' + row.indexdef);

    const enums = await client.query(
      'SELECT t.typname AS name, count(e.enumlabel)::int AS total ' +
      'FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid ' +
      'JOIN pg_namespace n ON n.oid = t.typnamespace ' +
      "WHERE n.nspname = 'public' GROUP BY t.typname ORDER BY t.typname"
    );
    const schemaEnums = (committedText.match(/^enum\s+\w+/gm) || []).length;
    console.log('\nEnum: schema ' + schemaEnums + ', database ' + enums.rows.length);
    if (schemaEnums !== enums.rows.length) failures.push('Jumlah enum berbeda');

    const foreignKeys = await client.query(
      'SELECT count(*)::int AS total FROM pg_constraint c ' +
      'JOIN pg_class t ON t.oid = c.conrelid ' +
      'JOIN pg_namespace n ON n.oid = t.relnamespace ' +
      "WHERE n.nspname = 'public' AND c.contype = 'f'"
    );
    console.log('Foreign key di database: ' + foreignKeys.rows[0].total);
  } finally {
    client.release();
    await pool.end();
  }
  console.log('\n=== 4. OBJEK DI LUAR DATAMODEL PRISMA (informasi) ===');
  const pool2 = new Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 15000 });
  const client2 = await pool2.connect();
  try {
    const functions = await client2.query(
      'SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace ' +
      "WHERE n.nspname = 'public' ORDER BY p.proname"
    );
    const fnNames = functions.rows.map(function (row) { return row.proname; });
    console.log('Function public: ' + (fnNames.length ? fnNames.join(', ') : 'tidak ada'));

    const triggers = await client2.query(
      'SELECT t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid ' +
      'JOIN pg_namespace n ON n.oid = c.relnamespace ' +
      "WHERE n.nspname = 'public' AND NOT t.tgisinternal"
    );
    console.log('Trigger non-internal: ' + triggers.rows.length);

    const policies = await client2.query(
      "SELECT count(*)::int AS total FROM pg_policies WHERE schemaname = 'public'"
    );
    const rls = await client2.query(
      'SELECT count(*) FILTER (WHERE c.relrowsecurity)::int AS enabled, count(*)::int AS total ' +
      'FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace ' +
      "WHERE n.nspname = 'public' AND c.relkind = 'r'"
    );
    console.log('RLS aktif: ' + rls.rows[0].enabled + '/' + rls.rows[0].total +
      ' tabel; policy: ' + policies.rows[0].total);

    const grants = await client2.query(
      'SELECT grantee, count(*)::int AS total FROM information_schema.role_table_grants ' +
      "WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated') " +
      'GROUP BY grantee ORDER BY grantee'
    );
    const grantText = grants.rows.map(function (row) { return row.grantee + '=' + row.total; });
    console.log('Grant anon/authenticated: ' + (grantText.length ? grantText.join(', ') : 'tidak ada'));
    if (rls.rows[0].enabled === 0 && grants.rows.length > 0) {
      console.log('RISIKO: RLS tidak aktif tetapi anon/authenticated memiliki grant tabel.');
      console.log('Akses REST Supabase dengan anon key dapat membaca/mengubah data.');
    }
  } finally {
    client2.release();
    await pool2.end();
  }

  fs.rmSync(tmpDir, { recursive: true, force: true });

  console.log('\n=== 5. HASIL ===');
  if (failures.length === 0) {
    console.log('PASS: schema.prisma dan database aktual tidak memiliki perbedaan pada');
    console.log('seluruh aspek yang direpresentasikan Prisma (tabel, kolom, tipe data,');
    console.log('nullability, default, enum, primary key, unique, index, foreign key,');
    console.log('dan aksi referensial onDelete/onUpdate).');
  } else {
    console.log('FAIL: ' + failures.length + ' perbedaan ditemukan:');
    for (const item of failures) console.log('- ' + item);
    process.exitCode = 1;
  }
};

main().catch(function (error) {
  console.error('Verifikasi gagal: ' + error.message);
  process.exitCode = 1;
});
