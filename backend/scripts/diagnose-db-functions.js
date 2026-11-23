#!/usr/bin/env node
/**
 * Diagnostik READ-ONLY: bandingkan definisi function PL/pgSQL di database
 * dengan definisi terakhir pada `prisma/migrations`.
 *
 * Tidak melakukan DDL/DML. Berguna ketika migration berstatus "applied" tetapi
 * function di database tertimpa versi lama (drift), sehingga endpoint yang
 * bergantung pada function gagal saat runtime. Setiap perbedaan dilaporkan
 * sebagai pasangan baris DB vs migration agar penyebabnya dapat diperiksa.
 *
 * Jalankan: node scripts/diagnose-db-functions.js
 */
'use strict';

const path = require('node:path');
const fs = require('node:fs');
const { Pool } = require('pg');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const MIGRATIONS_DIR = path.resolve(__dirname, '..', 'prisma', 'migrations');
const FUNCTIONS = [
  'create_event_order',
  'simulate_event_payment',
  'expire_event_order_reservations',
  'moderate_event',
];

const TYPE_WORDS = /\b(uuid|text|boolean|jsonb|integer|timestamptz|void)\b/gi;

const stripHeader = (sql) => {
  const lines = String(sql).split('\n');
  let end = 0;
  if (lines[0] && lines[0].includes('CREATE OR REPLACE FUNCTION')) {
    let open = 0;
    let started = false;
    for (let i = 0; i < lines.length; i += 1) {
      for (const char of lines[i]) {
        if (char === '(') { open += 1; started = true; }
        if (char === ')') open -= 1;
      }
      end = i;
      if (started && open === 0) {
        if (lines[i].includes(' AS ') || lines[i].includes(' AS $$') || lines[i].trim() === 'AS') break;
      }
    }
  }
  return lines.slice(end + 1).join('\n');
};

const normalizeLine = (line) => String(line)
  .replace(/\$function\$|\$\$/g, ' ')
  .replace(/\binto\s+\(([a-z_]+)\)/gi, 'into $1')
  .replace(/timestamp with time zone/gi, 'timestamptz')
  .replace(TYPE_WORDS, (m) => m.toLowerCase())
  .replace(/\bset\s+search_path\b[^;]*/gi, 'set search_path')
  .replace(/\s+/g, ' ')
  .replace(/\s*([(),;])\s*/g, '$1')
  .replace(/\s*=\s*/g, '=')
  .replace(/\bnull\b\s*/gi, '')
  .trim()
  .toLowerCase();

const signatureLine = (lines) => lines.find((line) => line.includes('(') && line.includes(')')) || '';

const normalizeLines = (sql) => String(sql)
  .replace(/;/g, '')
  .split('\n')
  .map(normalizeLine)
  .filter((line) => line.length > 0 && line !== '$$');

/** Definisi function terakhir per nama pada seluruh migration (urut nama folder). */
const latestMigrationDefinitions = () => {
  const dirs = fs.readdirSync(MIGRATIONS_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  const latest = {};
  for (const dir of dirs) {
    const file = path.join(MIGRATIONS_DIR, dir, 'migration.sql');
    if (!fs.existsSync(file)) continue;
    const sql = fs.readFileSync(file, 'utf8');
    for (const block of sql.match(/CREATE OR REPLACE FUNCTION[\s\S]*?\n\$\$;/g) || []) {
      const name = (block.match(/CREATE OR REPLACE FUNCTION\s+(?:public\.)?(\w+)/) || [])[1];
      if (!name) continue;
      latest[name] = { migration: dir, sql: block };
    }
  }
  return latest;
};

const main = async () => {
  if (process.argv.includes('--export')) {
    const expected = latestMigrationDefinitions();
    const blocks = FUNCTIONS.filter((name) => expected[name])
      .map((name) => `-- ${name} (migration ${expected[name].migration})\n${expected[name].sql}`);
    console.log(blocks.join('\n\n'));
    return;
  }
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL tidak tersedia');
  const expected = latestMigrationDefinitions();
  const pool = new Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 20000 });
  const client = await pool.connect();
  const problems = [];
  try {
    const applied = await client.query(
      'SELECT migration_name FROM _prisma_migrations WHERE finished_at IS NOT NULL ORDER BY migration_name'
    );
    console.log(`Migration tercatat applied: ${applied.rows.length}`);
    for (const row of applied.rows) console.log(`  - ${row.migration_name}`);

    const dbFunctions = await client.query(
      `SELECT p.proname, pg_get_functiondef(p.oid) AS def
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = ANY($1::text[])`,
      [FUNCTIONS]
    );
    const byName = Object.fromEntries(dbFunctions.rows.map((row) => [row.proname, row.def]));

    console.log('\nPerbandingan function database vs migration terakhir:');
    for (const name of FUNCTIONS) {
      const dbDef = byName[name];
      const want = expected[name];
      if (!dbDef) {
        console.log(`  ${name}: TIDAK ADA di database`);
        problems.push(`${name}: fungsi tidak ada di database`);
        continue;
      }
      if (!want) {
        console.log(`  ${name}: ada di database, tidak didefinisikan di migration`);
        continue;
      }
      const dbLines = normalizeLines(stripHeader(dbDef));
      const wantLines = normalizeLines(stripHeader(want.sql));
      const missingInDb = wantLines.filter((line) => !dbLines.includes(line));
      const extraInDb = dbLines.filter((line) => !wantLines.includes(line));
      const same = missingInDb.length === 0 && extraInDb.length === 0;
      console.log(`  ${name}: ${same ? 'SAMA' : 'BERBEDA'} (migration ${want.migration})`);
      if (!same) {
        console.log(`      signature DB  : ${signatureLine(normalizeLines(dbDef))}`);
        console.log(`      signature migr: ${signatureLine(normalizeLines(want.sql))}`);
        for (const line of missingInDb.slice(0, 4)) console.log(`      ada di migration, tidak di DB: ${line}`);
        for (const line of extraInDb.slice(0, 4)) console.log(`      ada di DB, tidak di migration: ${line}`);
        const rest = Math.max(0, missingInDb.length - 4) + Math.max(0, extraInDb.length - 4);
        if (rest > 0) console.log(`      (+${rest} baris lain berbeda)`);
        problems.push(`${name}: definisi database berbeda dari migration ${want.migration}`);
      }
    }
  } finally {
    client.release();
    await pool.end();
  }

  console.log('\n=== HASIL ===');
  if (problems.length === 0) {
    console.log('PASS: function database sesuai definisi migration terakhir.');
  } else {
    console.log(`FAIL: ${problems.length} drift terdeteksi:`);
    problems.forEach((problem) => console.log(`- ${problem}`));
    process.exitCode = 1;
  }
};

main().catch((error) => {
  console.error('Diagnostik gagal:', error.message);
  process.exitCode = 1;
});

module.exports = { latestMigrationDefinitions, normalizeLines, stripHeader, main };
