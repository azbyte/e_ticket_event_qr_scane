/**
 * DEPRECATED: was previously used to create Supabase JS clients.
 * All controllers now use direct PostgreSQL via ../config/db.
 * This module is kept for compatibility but does not start a client.
 */

const { query, getOne } = require('./db');

const supabase = { query, getOne };
const supabaseAdmin = { query, getOne };

module.exports = { supabase, supabaseAdmin, query, getOne };
