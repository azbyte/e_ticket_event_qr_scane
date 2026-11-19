const { Router } = require('express');
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const controller = require('../controllers/planController');
const router = Router();

// Public catalog returns only ACTIVE plans; admin endpoints manage the catalog.
router.get('/admin/all', authMiddleware, allowRoles('admin'), controller.listAllPlans);

router.get('/', controller.listPlans);
router.get('/:id', controller.getPlan);
router.post('/admin', authMiddleware, allowRoles('admin'), controller.createPlan);
router.put('/admin/:id', authMiddleware, allowRoles('admin'), controller.updatePlan);
router.delete('/admin/:id', authMiddleware, allowRoles('admin'), controller.deletePlan);

module.exports = router;
