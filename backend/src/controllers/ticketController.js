const asyncHandler = require('express-async-handler');
const jwt = require('jsonwebtoken');
const QRCode = require('qrcode');
const { supabase } = require('../config/supabase');
const config = require('../config/env');

/**
 * @desc    Buy / create ticket for an event
 * @route   POST /api/tickets
 * @access  Private
 */
const createTicket = asyncHandler(async (req, res) => {
  const { event_id } = req.body;

  if (!event_id) {
    res.status(400);
    throw new Error('Event ID is required');
  }

  // Check event exists and has tickets
  const { data: event, error: eventError } = await supabase
    .from('events')
    .select('*')
    .eq('id', event_id)
    .single();

  if (eventError || !event) {
    res.status(404);
    throw new Error('Event not found');
  }

  // Generate unique ticket code
  const ticketCode = `TKT-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

  // Generate QR code data (contains ticket code + event id + user id)
  const qrPayload = JSON.stringify({
    ticket_code: ticketCode,
    event_id,
    user_id: req.user.id,
    issued_at: new Date().toISOString(),
  });

  const qrCodeDataUrl = await QRCode.toDataURL(qrPayload);

  const { data: ticket, error } = await supabase
    .from('tickets')
    .insert([
      {
        ticket_code: ticketCode,
        event_id,
        user_id: req.user.id,
        qr_code_data: qrCodeDataUrl,
        status: 'active',
        purchased_at: new Date().toISOString(),
      },
    ])
    .select()
    .single();

  if (error) throw error;

  res.status(201).json({
    success: true,
    ticket: {
      ...ticket,
      qr_code: qrCodeDataUrl, // base64 image for mobile to display
    },
  });
});

/**
 * @desc    Get user tickets
 * @route   GET /api/tickets/my-tickets
 * @access  Private
 */
const getMyTickets = asyncHandler(async (req, res) => {
  const { data: tickets, error } = await supabase
    .from('tickets')
    .select(`, events(*)`)
    .eq('user_id', req.user.id)
    .order('purchased_at', { ascending: false });

  if (error) throw error;

  res.json({ success: true, count: tickets.length, tickets });
});

/**
 * @desc    Verify QR code ticket (scan at event entrance)
 * @route   POST /api/tickets/verify
 * @access  Private (organizer/staff)
 */
const verifyTicket = asyncHandler(async (req, res) => {
  const { ticket_code } = req.body;

  if (!ticket_code) {
    res.status(400);
    throw new Error('Ticket code is required');
  }

  const { data: ticket, error } = await supabase
    .from('tickets')
    .select(`, events(*), profiles!inner(user_id, name, email)`)
    .eq('ticket_code', ticket_code)
    .single();

  if (error || !ticket) {
    res.status(404);
    throw new Error('Ticket not found');
  }

  if (ticket.status === 'used') {
    return res.status(400).json({
      success: false,
      message: 'Ticket already used',
      ticket,
    });
  }

  // Mark as used
  const { data: updated, error: updateError } = await supabase
    .from('tickets')
    .update({ status: 'used', used_at: new Date().toISOString() })
    .eq('ticket_code', ticket_code)
    .select()
    .single();

  if (updateError) throw updateError;

  res.json({
    success: true,
    message: 'Ticket verified successfully',
    ticket: updated,
  });
});

module.exports = { createTicket, getMyTickets, verifyTicket };