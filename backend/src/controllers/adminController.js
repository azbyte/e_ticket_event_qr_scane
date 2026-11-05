const asyncHandler = require('express-async-handler');
const { supabaseAdmin } = require('../config/supabase');

const listAccounts = asyncHandler(async (req, res) => {
  let query = supabaseAdmin
    .from('profiles').select('id, name, email, username, role, avatar_url, created_at, disabled_at');
  if (req.query.role) query = query.eq('role', req.query.role);
  const { data, error } = await query.order('created_at', { ascending: false });
  if (error) throw error;
  res.json({ success: true, count: data.length, accounts: data });
});

const updateAccountStatus = asyncHandler(async (req, res) => {
  if (req.params.id === req.user.id) {
    res.status(400);
    throw new Error('Administrators cannot disable their own account');
  }
  const disabled_at = req.body.disabled ? new Date().toISOString() : null;
  const { data, error } = await supabaseAdmin.from('profiles')
    .update({ disabled_at }).eq('id', req.params.id)
    .select('id, name, email, role, disabled_at').maybeSingle();
  if (error) throw error;
  if (!data) { res.status(404); throw new Error('Account not found'); }
  res.json({ success: true, user: data });
});

module.exports = { listAccounts, updateAccountStatus };