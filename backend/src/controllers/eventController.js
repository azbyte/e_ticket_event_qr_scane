const asyncHandler = require('express-async-handler');
const { supabase } = require('../config/supabase');

/**
 * @desc    Get all events
 * @route   GET /api/events
 * @access  Public
 */
const getEvents = asyncHandler(async (req, res) => {
  const { data: events, error } = await supabase
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
  const { data: event, error } = await supabase
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

/**
 * @desc    Create event
 * @route   POST /api/events
 * @access  Private (organizer)
 */
const createEvent = asyncHandler(async (req, res) => {
  const { title, description, date, location, total_tickets, price } = req.body;

  if (!title || !date || !location) {
    res.status(400);
    throw new Error('Please provide title, date, and location');
  }

  const { data: event, error } = await supabase
    .from('events')
    .insert([
      {
        title,
        description,
        event_date: date,
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
  const { data: event, error } = await supabase
    .from('events')
    .update(req.body)
    .eq('id', req.params.id)
    .eq('created_by', req.user.id)
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
  const { error } = await supabase
    .from('events')
    .delete()
    .eq('id', req.params.id)
    .eq('created_by', req.user.id);

  if (error) throw error;

  res.json({ success: true, message: 'Event deleted' });
});

module.exports = { getEvents, getEventById, createEvent, updateEvent, deleteEvent };