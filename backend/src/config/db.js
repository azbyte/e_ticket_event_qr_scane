const { Pool } = require('pg');

/**
 * Koneksi langsung ke PostgreSQL (Supabase pooled) menggunakan DATABASE_URL.
 * Backend adalah gatekeeper yang tepercaya; semua otorisasi dilakukan di sisi
 * server, klien aplikasi tidak pernah menerima kunci database.
 */
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

pool.on('error', (err) => {
  console.error('Unexpected pg pool error:', err.message);
});

/**
 * Jalankan query parameterized dan kembalikan baris.
 * @param {string} sql
 * @param {Array} params
 * @returns {Promise<Array>}
 */
async function query(sql, params = []) {
  const res = await pool.query(sql, params);
  return res.rows;
}

/**
 * Jalankan query dan kembalikan satu baris (atau null jika tidak ada).
 */
async function getOne(sql, params = []) {
  const rows = await query(sql, params);
  return rows[0] || null;
}

// Dinamakan supabase untuk kompatibilitas terhadap kode lama; mengarah ke
// koneksi PostgreSQL langsung, bukan ke API REST Supabase.
const supabase = { query, getOne };

module.exports = { pool, query, getOne, supabase };

