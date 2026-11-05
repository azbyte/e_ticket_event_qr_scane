const asyncHandler = require('express-async-handler');
const bcrypt = require('bcryptjs');
const { supabaseAdmin } = require('../config/supabase');
const authService = require('../services/authService');
const { validateEmail, validatePassword } = require('../utils/validators');
const { USER_ROLES } = require('../utils/constants');

/**
 * @desc    Register new user
 * @route   POST /api/auth/register
 * @access  Public
 */
const registerUser = asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;

  if (!name || !email || !password) {
    res.status(400);
    throw new Error('Please provide name, email, and password');
  }

  if (!validateEmail(email)) {
    res.status(400);
    throw new Error('Invalid email format');
  }

  if (!validatePassword(password)) {
    res.status(400);
    throw new Error('Password must be at least 6 characters');
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Check if user exists via Supabase
  const { data: existingUser, error: findError } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .eq('email', normalizedEmail)
    .maybeSingle();

  if (findError) throw findError;
  if (existingUser) {
    res.status(400);
    throw new Error('User already exists');
  }

  // Create auth user in Supabase Auth
  const baseUsername = normalizedEmail.split('@')[0];
  const { count: usernameCount, error: usernameError } = await supabaseAdmin
    .from('profiles').select('id', { count: 'exact', head: true }).eq('username', baseUsername);
  if (usernameError) throw usernameError;
  const username = usernameCount ? `${baseUsername}_${Date.now().toString(36)}` : baseUsername;
  const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
    email: normalizedEmail,
    password,
    email_confirm: true,
    user_metadata: { name, username, role: USER_ROLES.ORGANIZER },
  });

  if (authError) throw authError;

  // Create profile in public.profiles table
  const hashedPassword = await authService.hashPassword(password);
  const { error: profileError } = await supabaseAdmin.from('profiles').insert([
    {
      id: authData.user.id,
      name,
      email: normalizedEmail,
      password_hash: hashedPassword,
      username,
      role: USER_ROLES.ORGANIZER,
      created_at: new Date().toISOString(),
    },
  ]);

  if (profileError) throw profileError;

  // Generate JWT
  const token = authService.generateToken({ id: authData.user.id, email: normalizedEmail, role: USER_ROLES.ORGANIZER });

  res.status(201).json({
    success: true,
    token,
    user: { id: authData.user.id, name, email: normalizedEmail, username, role: USER_ROLES.ORGANIZER },
  });
});

/**
 * @desc    Login user
 * @route   POST /api/auth/login
 * @access  Public
 */
const loginUser = asyncHandler(async (req, res) => {
  const { password } = req.body;
  const identity = String(req.body.email || req.body.username || '').trim().toLowerCase();

  if (!identity || !password) {
    return res.status(400).json({ success: false, message: 'Email/username and password are required' });
  }

  // Resolve email or username through profile data; never accept a role from the client.
  let lookup = supabaseAdmin
    .from('profiles')
    .select('id, name, email, username, password_hash, role, avatar_url, created_at, disabled_at')
    .eq('email', identity);
  let { data: user, error } = await lookup.maybeSingle();

  if (!user && !identity.includes('@')) {
    ({ data: user, error } = await supabaseAdmin
      .from('profiles')
      .select('id, name, email, username, password_hash, role, avatar_url, created_at, disabled_at')
      .eq('username', identity)
      .maybeSingle());
  }

  if (error || !user) {
    res.status(401);
    throw new Error('Invalid credentials');
  }
  if (user.disabled_at) {
    res.status(401);
    throw new Error('This account is disabled');
  }

  // Compare password
  const isMatch = user.password_hash && await bcrypt.compare(password, user.password_hash);
  if (!isMatch) {
    res.status(401);
    throw new Error('Invalid credentials');
  }

  // Generate JWT
  const token = authService.generateToken(user);

  res.json({
    success: true,
    token,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      avatar_url: user.avatar_url,
      created_at: user.created_at,
    },
  });
});

/**
 * @desc    Get user profile
 * @route   GET /api/auth/me
 * @access  Private
 */
const getMe = asyncHandler(async (req, res) => {
  const { data: user, error } = await supabaseAdmin
    .from('profiles')
    .select('id, name, email, username, role, avatar_url, created_at')
    .eq('id', req.user.id)
    .single();

  if (error || !user) {
    res.status(404);
    throw new Error('User not found');
  }

  res.json({ success: true, user });
});

const updateMe = asyncHandler(async (req, res) => {
  const updates = {};
  if (typeof req.body.name === 'string' && req.body.name.trim()) updates.name = req.body.name.trim();
  if (typeof req.body.avatar_url === 'string') updates.avatar_url = req.body.avatar_url.trim() || null;
  if (Object.keys(updates).length === 0) {
    res.status(400);
    throw new Error('Please provide profile fields to update');
  }
  const { data: user, error } = await supabaseAdmin
    .from('profiles')
    .update(updates)
    .eq('id', req.user.id)
    .select('id, name, email, username, role, avatar_url, created_at')
    .single();
  if (error) throw error;
  res.json({ success: true, user });
});

const logoutUser = asyncHandler(async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (token) {
    const decoded = require('jsonwebtoken').decode(token);
    const expiresAt = new Date((decoded?.exp || Math.floor(Date.now() / 1000) + 3600) * 1000).toISOString();
    const { error } = await supabaseAdmin.from('revoked_tokens').upsert({
      token_hash: authService.hashToken(token), expires_at: expiresAt,
    }, { onConflict: 'token_hash' });
    if (error) throw error;
  }
  res.json({ success: true, message: 'Logged out successfully' });
});

module.exports = { registerUser, loginUser, getMe, updateMe, logoutUser };