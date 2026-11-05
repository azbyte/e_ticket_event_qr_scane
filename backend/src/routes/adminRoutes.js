const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const { listAccounts, updateAccountStatus } = require('../controllers/adminController');

router.use(authMiddleware, allowRoles('admin'));
router.get('/accounts', listAccounts);
router.get('/organizers', (req, res, next) => { req.query.role = 'organizer'; next(); }, listAccounts);
router.put('/accounts/:id/status', updateAccountStatus);

module.exports = router;