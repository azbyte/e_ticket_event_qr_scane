const express = require('express');
const router = express.Router();
const {
  getEvents,
  getMyEvents,
  getAllEvents,
  getEventById,
  createEvent,
  updateEvent,
  deleteEvent,
  submitForReview,
  getEventMembers,
  addEventMember,
  updateEventMemberPermissions,
  removeEventMember,
} = require('../controllers/eventController');
const { authMiddleware, optionalAuth } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const ticketTypes = require('../controllers/ticketTypeController');
const eventMetrics = require('../controllers/eventMetricsController');
const { listEventAttendees } = require('../controllers/checkInController');
const {
  createInvitation,
  listInvitations,
  revokeInvitation,
} = require('../controllers/eventInvitationController');

router.get('/public', getEvents);
router.get('/', authMiddleware, allowRoles('admin'), getAllEvents);
router.get('/mine', authMiddleware, allowRoles('organizer'), getMyEvents);
router.get('/:id/summary', authMiddleware, allowRoles('organizer', 'admin'), eventMetrics.getEventSummary);
router.get('/:id/sales', authMiddleware, allowRoles('organizer', 'admin'), eventMetrics.getEventSalesPoints);
router.get('/:eventId/ticket-types', optionalAuth, ticketTypes.listEventTicketTypes);
router.get('/:eventId/attendees', authMiddleware, allowRoles('organizer', 'admin'), listEventAttendees);
router.get('/:eventId/invitations', authMiddleware, allowRoles('organizer', 'admin'), listInvitations);
router.post('/:eventId/invitations', authMiddleware, allowRoles('organizer', 'admin'), createInvitation);
router.delete('/:eventId/invitations/:invitationId', authMiddleware, allowRoles('organizer', 'admin'), revokeInvitation);
router.post('/:eventId/ticket-types', authMiddleware, allowRoles('organizer'), ticketTypes.createTicketType);
router.put('/:eventId/ticket-types/:ticketTypeId', authMiddleware, allowRoles('organizer'), ticketTypes.updateTicketType);
router.delete('/:eventId/ticket-types/:ticketTypeId', authMiddleware, allowRoles('organizer'), ticketTypes.deleteTicketType);
router.get('/:id/members', authMiddleware, allowRoles('organizer'), getEventMembers);
router.post('/:id/members', authMiddleware, allowRoles('organizer'), addEventMember);
router.put('/:id/members/:userId/permissions', authMiddleware, allowRoles('organizer'), updateEventMemberPermissions);
router.delete('/:id/members/:userId', authMiddleware, allowRoles('organizer'), removeEventMember);
router.get('/:id', optionalAuth, getEventById);
router.post('/:id/submit-review', authMiddleware, allowRoles('organizer'), submitForReview);
router.post('/', authMiddleware, allowRoles('organizer', 'admin'), createEvent);
router.put('/:id', authMiddleware, allowRoles('organizer', 'admin'), updateEvent);
router.delete('/:id', authMiddleware, allowRoles('organizer', 'admin'), deleteEvent);

module.exports = router;