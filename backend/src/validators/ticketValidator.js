const { body } = require('express-validator');

const createTicketValidator = [
  body('event_id').notEmpty().withMessage('Event ID is required'),
];

const verifyTicketValidator = [
  body('ticket_code').notEmpty().withMessage('Ticket code is required'),
];

module.exports = { createTicketValidator, verifyTicketValidator };