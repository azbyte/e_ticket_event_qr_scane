const { supabase } = require('../config/supabase');

/**
 * Ticket model - wrappers around Supabase tickets table
 */
const Ticket = {
  async create(ticketData) {
    const { data, error } = await supabase
      .from('tickets')
      .insert([ticketData])
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async getByUserId(userId) {
    const { data, error } = await supabase
      .from('tickets')
      .select(`, events(*)`)
      .eq('user_id', userId)
      .order('purchased_at', { ascending: false });
    if (error) throw error;
    return data;
  },

  async getByCode(ticketCode) {
    const { data, error } = await supabase
      .from('tickets')
      .select(`, events(*), profiles!inner(id, name, email)`)
      .eq('ticket_code', ticketCode)
      .single();
    if (error && error.code !== 'PGRST116') throw error;
    return data;
  },

  async markAsUsed(ticketCode) {
    const { data, error } = await supabase
      .from('tickets')
      .update({ status: 'used', used_at: new Date().toISOString() })
      .eq('ticket_code', ticketCode)
      .select()
      .single();
    if (error) throw error;
    return data;
  },
};

module.exports = Ticket;