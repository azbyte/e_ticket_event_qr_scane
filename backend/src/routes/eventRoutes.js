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
  getEventMembers,
  addEventMember,
  removeEventMember,
} = require('../controllers/eventController');
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');

router.get('/public', getEvents);
router.get('/', authMiddleware, allowRoles('admin'), getAllEvents);
router.get('/mine', authMiddleware, allowRoles('organizer'), getMyEvents);
router.get('/:id/members', authMiddleware, allowRoles('organizer'), getEventMembers);
router.post('/:id/members', authMiddleware, allowRoles('organizer'), addEventMember);
router.delete('/:id/members/:userId', authMiddleware, allowRoles('organizer'), removeEventMember);
router.get('/:id', getEventById);
router.post('/', authMiddleware, allowRoles('organizer', 'admin'), createEvent);
router.put('/:id', authMiddleware, allowRoles('organizer', 'admin'), updateEvent);
router.delete('/:id', authMiddleware, allowRoles('organizer', 'admin'), deleteEvent);

module.exports = router;