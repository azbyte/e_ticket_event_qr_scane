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
  publishEvent,
  getEventMembers,
  addEventMember,
  updateEventMemberPermissions,
  removeEventMember,
} = require('../controllers/eventController');
const { authMiddleware, optionalAuth } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const ticketTypes = require('../controllers/ticketTypeController');
const eventMetrics = require('../controllers/eventMetricsController');
const {
  listEventAttendees,
  exportEventAttendeesCsv,
  getEventOrders,
} = require('../controllers/checkInController');
const {
  createInvitation,
  listInvitations,
  revokeInvitation,
  acceptInvitation,
  myInvitations,
  getInvitationPreview,
} = require('../controllers/eventInvitationController');
const ticketDesign = require('../controllers/ticketDesignController');

/**
 * Domain event: event, kategori tiket, peserta, dan undangan staf.
 *
 * Menggabungkan `eventRoutes.js` + `ticketTypeRoutes.js` + `invitationsRoutes.js`.
 * Di-mount pada `/api`, sehingga path tetap sama:
 *   /api/events/**, /api/ticket-types/**, /api/invitations/**
 */

const eventRouter = express.Router();

eventRouter.get('/public', getEvents);
eventRouter.get('/', authMiddleware, allowRoles('admin'), getAllEvents);
eventRouter.get('/mine', authMiddleware, allowRoles('organizer'), getMyEvents);
eventRouter.get('/:id/summary', authMiddleware, allowRoles('organizer', 'admin'), eventMetrics.getEventSummary);
eventRouter.get('/:id/sales', authMiddleware, allowRoles('organizer', 'admin'), eventMetrics.getEventSalesPoints);
eventRouter.get('/:eventId/ticket-types', optionalAuth, ticketTypes.listEventTicketTypes);
// Desain tiket (PRD §5). Hanya pemilik event/Admin; divalidasi di controller.
eventRouter.get('/:eventId/ticket-design', authMiddleware, allowRoles('organizer', 'admin'), ticketDesign.getEventTicketDesign);
eventRouter.put('/:eventId/ticket-design', authMiddleware, allowRoles('organizer', 'admin'), ticketDesign.saveTicketDesign);
eventRouter.delete('/:eventId/ticket-design', authMiddleware, allowRoles('organizer', 'admin'), ticketDesign.deleteTicketDesign);
// Daftar peserta: `staff` harus lolos gate route, sedangkan otorisasi sebenarnya
// berbasis permission `VIEW_PARTICIPANTS` di controller (D3-1 K4).
eventRouter.get('/:eventId/attendees', authMiddleware, allowRoles('organizer', 'admin', 'staff'), listEventAttendees);
eventRouter.get('/:eventId/invitations', authMiddleware, allowRoles('organizer', 'admin'), listInvitations);
eventRouter.post('/:eventId/invitations', authMiddleware, allowRoles('organizer', 'admin'), createInvitation);
eventRouter.delete('/:eventId/invitations/:invitationId', authMiddleware, allowRoles('organizer', 'admin'), revokeInvitation);
eventRouter.post('/:eventId/ticket-types', authMiddleware, allowRoles('organizer'), ticketTypes.createTicketType);
eventRouter.put('/:eventId/ticket-types/:ticketTypeId', authMiddleware, allowRoles('organizer'), ticketTypes.updateTicketType);
eventRouter.delete('/:eventId/ticket-types/:ticketTypeId', authMiddleware, allowRoles('organizer'), ticketTypes.deleteTicketType);
eventRouter.get('/:id/members', authMiddleware, allowRoles('organizer'), getEventMembers);
eventRouter.post('/:id/members', authMiddleware, allowRoles('organizer'), addEventMember);
eventRouter.put('/:id/members/:userId/permissions', authMiddleware, allowRoles('organizer'), updateEventMemberPermissions);
eventRouter.delete('/:id/members/:userId', authMiddleware, allowRoles('organizer'), removeEventMember);
eventRouter.get('/:id', optionalAuth, getEventById);
eventRouter.post('/:id/publish', authMiddleware, allowRoles('organizer'), publishEvent);
eventRouter.post('/:id/submit-review', authMiddleware, allowRoles('organizer'), submitForReview);
eventRouter.post('/', authMiddleware, allowRoles('organizer', 'admin'), createEvent);
eventRouter.put('/:id', authMiddleware, allowRoles('organizer', 'admin'), updateEvent);
eventRouter.delete('/:id', authMiddleware, allowRoles('organizer', 'admin'), deleteEvent);

// `ticket-types/:id` tetap tersedia untuk klien yang mengambil satu kategori
// tiket langsung (dipakai halaman publik).
const ticketTypeRouter = express.Router();
ticketTypeRouter.get('/:id', optionalAuth, ticketTypes.getTicketType);

// Rute statis harus dideklarasikan sebelum `/:token` agar tidak tertangkap
// sebagai token undangan.
const invitationRouter = express.Router();
invitationRouter.get('/me', authMiddleware, myInvitations);
invitationRouter.post('/:token/accept', authMiddleware, acceptInvitation);
// Pratinjau undangan publik (tanpa auth). Data minimal, tanpa PII lengkap.
invitationRouter.get('/:token', getInvitationPreview);

// Ekspor peserta & daftar order per event didaftarkan SEBELUM router `/events`
// agar tidak tertangkap pola `/:id`. Urutan ini sama dengan konfigurasi lama
// pada `app.js`.
router.get('/events/:id/attendees/export', authMiddleware, exportEventAttendeesCsv);
router.get('/events/:id/orders', authMiddleware, getEventOrders);
// Template desain tiket bersifat generik (tanpa data Organizer), jadi boleh
// diunduh tanpa login agar tautannya dapat dibuka dari browser mana pun.
router.get('/ticket-design-template', ticketDesign.downloadTemplate);
router.use('/events', eventRouter);
router.use('/ticket-types', ticketTypeRouter);
router.use('/invitations', invitationRouter);

module.exports = router;
