const asyncHandler = require('express-async-handler');
const { supabase, supabaseAdmin } = require('../config/supabase');

const eventDatabase = supabaseAdmin;

/**
 * @desc    Get all events
 * @route   GET /api/events
 * @access  Public
 */
const getEvents = asyncHandler(async (req, res) => {
  const { data: events, error } = await eventDatabase
    .from('events')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;

  res.json({ success: true, count: events.length, events });
});

/**
 * @desc    Get single event
 * @route   GET /api/events/:id
 * @access  Public
 */
const getEventById = asyncHandler(async (req, res) => {
  const { data: event, error } = await eventDatabase
    .from('events')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (error || !event) {
    res.status(404);
    throw new Error('Event not found');
  }

  res.json({ success: true, event });
});

const getAllEvents = asyncHandler(async (req, res) => {
  const { data: events, error } = await eventDatabase.from('events').select('*').order('created_at', { ascending: false });
  if (error) throw error;
  res.json({ success: true, count: events.length, events });
});

const getMyEvents = asyncHandler(async (req, res) => {
  const { data: events, error } = await eventDatabase
    .from('events').select('*').eq('created_by', req.user.id)
    .order('created_at', { ascending: false });
  if (error) throw error;
  res.json({ success: true, count: events.length, events });
});

/**
 * @desc    Create event
 * @route   POST /api/events
 * @access  Private (organizer)
 */
const createEvent = asyncHandler(async (req, res) => {
  const { title, description, date, event_date, location, total_tickets, price } = req.body;
  const eventDate = date || event_date;

  if (!title || !eventDate || !location) {
    res.status(400);
    throw new Error('Please provide title, date, and location');
  }

  const { data: event, error } = await eventDatabase
    .from('events')
    .insert([
      {
        title,
        description,
        event_date: eventDate,
        location,
        total_tickets: total_tickets || 0,
        price: price || 0,
        created_by: req.user.id,
        created_at: new Date().toISOString(),
      },
    ])
    .select()
    .single();

  if (error) throw error;

  res.status(201).json({ success: true, event });
});

/**
 * @desc    Update event
 * @route   PUT /api/events/:id
 * @access  Private (organizer)
 */
const updateEvent = asyncHandler(async (req, res) => {
  const updates = {};
  const fields = { title: 'title', description: 'description', location: 'location', total_tickets: 'total_tickets', price: 'price' };
  for (const [input, column] of Object.entries(fields)) {
    if (req.body[input] !== undefined) updates[column] = req.body[input];
  }
  if (req.body.date !== undefined || req.body.event_date !== undefined) {
    updates.event_date = req.body.date || req.body.event_date;
  }
  if (!Object.keys(updates).length) {
    res.status(400);
    throw new Error('Please provide event fields to update');
  }
  let query = eventDatabase
    .from('events')
    .update(updates)
    .eq('id', req.params.id);
  if (req.user.role !== 'admin') query = query.eq('created_by', req.user.id);
  const { data: event, error } = await query
    .select()
    .single();

  if (error || !event) {
    res.status(404);
    throw new Error('Event not found or unauthorized');
  }

  res.json({ success: true, event });
});

/**
 * @desc    Delete event
 * @route   DELETE /api/events/:id
 * @access  Private (organizer)
 */
const deleteEvent = asyncHandler(async (req, res) => {
  let query = eventDatabase
    .from('events')
    .delete()
    .eq('id', req.params.id);
  if (req.user.role !== 'admin') query = query.eq('created_by', req.user.id);
  const { data: deleted, error } = await query.select('id');

  if (error) throw error;
  if (!deleted || deleted.length === 0) {
    res.status(404);
    throw new Error('Event not found or unauthorized');
  }

  res.json({ success: true, message: 'Event deleted' });
});

const ensureEventOwner = async (eventId, userId) => {
  const { data, error } = await eventDatabase.from('events').select('id, created_by').eq('id', eventId).maybeSingle();
  if (error) throw error;
  if (!data) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (data.created_by !== userId) {
    const err = new Error('You do not own this event'); err.statusCode = 403; throw err;
  }
  return data;
};

const getEventMembers = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  const { data, error } = await eventDatabase.from('event_members')
    .select('user_id, role, created_at, profiles(id, name, email, username, avatar_url)')
    .eq('event_id', req.params.id).order('created_at', { ascending: true });
  if (error) throw error;
  res.json({ success: true, members: data });
});

const addEventMember = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  const identity = String(req.body.email || req.body.username || '').trim().toLowerCase();
  if (!identity) { res.status(400); throw new Error('Provide a member email or username'); }
  if (identity === req.user.id || identity === req.user.email) {
    res.status(400); throw new Error('The event owner cannot also be added as a member');
  }
  let query = eventDatabase.from('profiles').select('id, role').eq('email', identity);
  let { data: account, error } = await query.maybeSingle();
  if (!account && !identity.includes('@')) {
    ({ data: account, error } = await eventDatabase.from('profiles').select('id, role').eq('username', identity).maybeSingle());
  }
  if (error) throw error;
  if (!account) { res.status(404); throw new Error('Account not found'); }
  if (account.id === req.user.id) { res.status(400); throw new Error('The event owner cannot also be added as a member'); }
  const { data: member, error: insertError } = await eventDatabase.from('event_members')
    .insert({ event_id: req.params.id, user_id: account.id, role: 'staff' })
    .select('user_id, role, created_at, profiles(id, name, email, username, avatar_url)').single();
  if (insertError) {
    if (insertError.code === '23505') { res.status(409); throw new Error('This account is already a member of this event'); }
    throw insertError;
  }
  res.status(201).json({ success: true, member });
});

const removeEventMember = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  if (req.params.userId === req.user.id) { res.status(400); throw new Error('The event owner is not an event member'); }
  const { data: deleted, error } = await eventDatabase.from('event_members').delete()
    .eq('event_id', req.params.id).eq('user_id', req.params.userId).select('user_id');
  if (error) throw error;
  if (!deleted?.length) { res.status(404); throw new Error('Event member not found'); }
  res.json({ success: true, message: 'Event member removed' });
});

module.exports = { getEvents, getMyEvents, getAllEvents, getEventById, createEvent, updateEvent, deleteEvent, getEventMembers, addEventMember, removeEventMember };