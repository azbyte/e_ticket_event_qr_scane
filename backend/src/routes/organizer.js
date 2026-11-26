const express = require('express');
const router = express.Router();

const {
  getEventSummaries,
  getOrganizerOverview,
} = require('../controllers/eventMetricsController');
const organizerProfileController = require('../controllers/organizerProfileController');
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');

/**
 * Domain workspace Organizer.
 *
 * Menggabungkan `organizerRoutes.js` dan dua route profil Organizer yang
 * sebelumnya didaftarkan langsung di `app.js`. Di-mount pada `/api`, sehingga
 * path tetap sama:
 *   /api/organizer/overview, /api/organizer/events/summaries,
 *   /api/organizer/profile (GET & PUT)
 *
 * Gate `authMiddleware + allowRoles('organizer')` dipasang sekali di awal,
 * berlaku untuk seluruh route termasuk profil — sama seperti konfigurasi lama.
 */

const organizerRouter = express.Router();
organizerRouter.use(authMiddleware, allowRoles('organizer'));
organizerRouter.get('/overview', getOrganizerOverview);
organizerRouter.get('/events/summaries', getEventSummaries);
organizerRouter.get('/profile', organizerProfileController.getMyProfile);
organizerRouter.put('/profile', organizerProfileController.updateMyProfile);

router.use('/organizer', organizerRouter);

module.exports = router;
