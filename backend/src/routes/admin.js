const express = require('express');
const { authenticate, requireRoles } = require('../middleware/auth');
const { ROLES } = require('../utils/constants');
const { assignBus } = require('../controllers/adminController');

const router = express.Router();
router.use(authenticate, requireRoles(ROLES.ADMIN));
router.post('/assign-bus', assignBus);

module.exports = router;
