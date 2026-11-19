const express = require('express');
const router = express.Router();
const { getEventSummaries, getOrganizerOverview } = require('../controllers/eventMetricsController');
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');

router.use(authMiddleware, allowRoles('organizer'));
router.get('/overview', getOrganizerOverview);
router.get('/events/summaries', getEventSummaries);

module.exports = router;
