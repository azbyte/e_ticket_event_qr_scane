const asyncHandler = require('express-async-handler');
const bcrypt = require('bcryptjs');
const { query, getOne } = require('../config/db');
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

  // Cek apakah email sudah terdaftar di tabel profiles
  const existing = await getOne('SELECT id FROM profiles WHERE email = $1', [normalizedEmail]);
  if (existing) {
    res.status(400);
    throw new Error('User already exists');
  }

  // Buat username unik
  const baseUsername = normalizedEmail.split('@')[0];
  const usernameRows = await query('SELECT id FROM profiles WHERE username = $1', [baseUsername]);
  const username = usernameRows.length ? `${baseUsername}_${Date.now().toString(36)}` : baseUsername;

  const hashedPassword = await authService.hashPassword(password);
  const created = await getOne(
    `INSERT INTO profiles (id, name, email, password_hash, username, role, created_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
     RETURNING id, name, email, username, role`,
    [name, normalizedEmail, hashedPassword, username, USER_ROLES.ORGANIZER, new Date().toISOString()]
  );

  // Generate JWT
  const token = authService.generateToken({ id: created.id, email: created.email, role: created.role });

  res.status(201).json({
    success: true,
    token,
    user: { id: created.id, name: created.name, email: created.email, username: created.username, role: created.role },
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

  // Resolve email atau username melalui data profil; bukan menerima role dari klien.
  let user = await getOne(
    'SELECT id, name, email, username, password_hash, role, avatar_url, created_at, disabled_at FROM profiles WHERE email = $1',
    [identity]
  );
  if (!user && !identity.includes('@')) {
    user = await getOne(
      'SELECT id, name, email, username, password_hash, role, avatar_url, created_at, disabled_at FROM profiles WHERE username = $1',
      [identity]
    );
  }

  if (!user) {
    res.status(401);
    throw new Error('Invalid credentials');
  }
  if (user.disabled_at) {
    res.status(401);
    throw new Error('This account is disabled');
  }

  // Bandingkan password
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
  const user = await getOne(
    'SELECT id, name, email, username, role, avatar_url, created_at FROM profiles WHERE id = $1',
    [req.user.id]
  );

  if (!user) {
    res.status(404);
    throw new Error('User not found');
  }

  res.json({ success: true, user });
});

const updateMe = asyncHandler(async (req, res) => {
  const updates = {};
  const params = [];
  const setParts = [];
  let paramIndex = 1;

  if (typeof req.body.name === 'string' && req.body.name.trim()) {
    setParts.push(`name = $${paramIndex}`);
    params.push(req.body.name.trim());
    paramIndex += 1;
  }
  if (typeof req.body.avatar_url === 'string') {
    setParts.push(`avatar_url = $${paramIndex}`);
    params.push(req.body.avatar_url.trim() || null);
    paramIndex += 1;
  }
  if (setParts.length === 0) {
    res.status(400);
    throw new Error('Please provide profile fields to update');
  }

  params.push(req.user.id);
  const user = await getOne(
    `UPDATE profiles SET ${setParts.join(', ')} WHERE id = $${paramIndex}
     RETURNING id, name, email, username, role, avatar_url, created_at`,
    params
  );

  res.json({ success: true, user });
});

const logoutUser = asyncHandler(async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (token) {
    const decoded = require('jsonwebtoken').decode(token);
    const expiresAt = new Date((decoded?.exp || Math.floor(Date.now() / 1000) + 3600) * 1000).toISOString();
    await query(
      `INSERT INTO revoked_tokens (token_hash, expires_at) VALUES ($1, $2)
       ON CONFLICT (token_hash) DO UPDATE SET expires_at = EXCLUDED.expires_at`,
      [authService.hashToken(token), expiresAt]
    );
  }
  res.json({ success: true, message: 'Logged out successfully' });
});

module.exports = { registerUser, loginUser, getMe, updateMe, logoutUser };
