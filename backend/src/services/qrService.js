const QRCode = require('qrcode');

/**
 * QR Service - generate QR code data for tickets
 */
const qrService = {
  /**
   * Generate QR code payload for a ticket
   * @param {Object} ticket - ticket object
   * @returns {Promise<string>} base64 data URL of QR code
   */
  async generateTicketQR(ticket) {
    const payload = JSON.stringify({
      ticket_code: ticket.ticket_code,
      event_id: ticket.event_id,
      user_id: ticket.user_id,
      issued_at: ticket.purchased_at || new Date().toISOString(),
    });
    return QRCode.toDataURL(payload);
  },

  /**
   * Parse QR code data from scanned ticket
   * @param {string} qrData - raw QR string
   * @returns {Object} parsed ticket data
   */
  parseTicketQR(qrData) {
    try {
      return JSON.parse(qrData);
    } catch (error) {
      throw new Error('Invalid QR code format');
    }
  },
};

module.exports = qrService;