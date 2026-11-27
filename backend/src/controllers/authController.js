const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const authService = require('../services/authService');
const { validateEmail, validatePassword } = require('../utils/validators');
const { USER_ROLES } = require('../utils/constants');

/** HTTP status yang ikut terbawa saat error dilempar dari dalam transaksi. */
class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

/**
 * Susun username unik dari email di dalam transaksi yang sama dengan INSERT.
 * Menghindari celah race condition antar dua pendaftaran bersamaan.
 */
async function buildUniqueUsername(client, normalizedEmail) {
  const base =
    normalizedEmail.split('@')[0].replace(/[^a-z0-9._-]/g, '').slice(0, 40) || 'user';
  const isTaken = async (candidate) => {
    const found = await client.query('SELECT 1 FROM profiles WHERE username = $1 LIMIT 1', [candidate]);
    return found.rowCount > 0;
  };
  if (!(await isTaken(base))) return base;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const candidate = `${base}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
    if (!(await isTaken(candidate))) return candidate;
  }
  return `${base}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`;
}

/**
 * @desc    Register new user (registrasi publik selalu membuat akun Organizer)
 * @route   POST /api/auth/register
 * @access  Public
 */
const registerUser = asyncHandler(async (req, res) => {
  const { name, email, password, confirm_password: confirmPassword, password_confirmation: passwordConfirmation } = req.body;

  if (!name || !email || !password) {
    res.status(400);
    throw new Error('Please provide name, email, and password');
  }

  const submittedConfirmation = confirmPassword !== undefined ? confirmPassword : passwordConfirmation;
  if (submittedConfirmation !== undefined && submittedConfirmation !== password) {
    res.status(400);
    throw new Error('Password confirmation does not match');
  }

  const trimmedName = String(name).trim();
  if (!trimmedName) {
    res.status(400);
    throw new Error('Name is required');
  }

  if (!validateEmail(email)) {
    res.status(400);
    throw new Error('Invalid email format');
  }

  if (!validatePassword(password)) {
    res.status(400);
    throw new Error('Password must be at least 6 characters');
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  // Role tidak pernah diambil dari klien: registrasi publik selalu Organizer.
  const role = USER_ROLES.ORGANIZER;
  const hashedPassword = await authService.hashPassword(password);

  // Akun User (`profiles`) dan profil Organizer (`organizer_profiles`) dibuat
  // dalam SATU transaksi. Bila salah satu gagal, seluruh proses dibatalkan
  // sehingga tidak pernah tersisa akun User tanpa profil Organizer.
  const client = await pool.connect();
  let created;
  let organizerProfile;
  try {
    await client.query('BEGIN');

    const existing = await client.query('SELECT 1 FROM profiles WHERE email = $1', [normalizedEmail]);
    if (existing.rowCount > 0) throw new HttpError(400, 'User already exists');

    const username = await buildUniqueUsername(client, normalizedEmail);

    const inserted = await client.query(
      `INSERT INTO profiles (id, name, email, password_hash, username, role, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())
       RETURNING id, name, email, username, role, avatar_url, created_at`,
      [trimmedName, normalizedEmail, hashedPassword, username, role]
    );
    created = inserted.rows[0];

    const org = await client.query(
      `INSERT INTO organizer_profiles (id, user_id, contact_name, created_at, updated_at)
       VALUES (gen_random_uuid(), $1, $2, NOW(), NOW())
       ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
       RETURNING id, user_id, organization_name, contact_name`,
      [created.id, trimmedName]
    );
    organizerProfile = org.rows[0];

    await client.query('COMMIT');
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // transaksi sudah berakhir; abaikan
    }
    // 23505 = unique_violation (email bentrok karena balapan permintaan).
    if (error.code === '23505') {
      res.status(400);
      throw new Error('User already exists');
    }
    if (error.statusCode) res.status(error.statusCode);
    throw error;
  } finally {
    client.release();
  }

  const token = authService.generateToken({ id: created.id, email: created.email, role: created.role });

  res.status(201).json({
    success: true,
    token,
    user: {
      id: created.id,
      name: created.name,
      email: created.email,
      username: created.username,
      role: created.role,
      avatar_url: created.avatar_url,
      created_at: created.created_at,
      organizer_profile_id: organizerProfile ? organizerProfile.id : null,
    },
  });
});

/**
 * @desc    Login user
 * @route   POST /api/auth/login
 * @access  Public
 */
const loginUser = asyncHandler(async (req, res) => {
  const rawPassword = req.body.password;
  const password = typeof rawPassword === 'string' ? rawPassword : '';
  const identity = String(req.body.email || req.body.username || '').trim().toLowerCase();

  if (!identity || !password) {
    return res.status(400).json({ success: false, message: 'Email/username and password are required' });
  }

  // Resolve email atau username melalui data profil; bukan menerima role dari klien.
  let user = await getOne(
    'SELECT id, name, email, username, password_hash, role, avatar_url, created_at, disabled_at FROM profiles WHERE email = $1',
    [identity]
  );
  if (!user) {
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

  // Bandingkan password. Hash yang tidak dikenal/rusak harus diperlakukan
  // sebagai kredensial tidak valid (401), bukan error 500.
  let isMatch = false;
  if (user.password_hash) {
    try {
      isMatch = await authService.comparePassword(password, user.password_hash);
    } catch (_) {
      isMatch = false;
    }
  }
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
