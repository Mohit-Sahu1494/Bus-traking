const express = require('express');
const { authenticate, requireRoles } = require('../middleware/auth');
const { ROLES } = require('../utils/constants');
const c = require('../controllers/driverController');

const router = express.Router();
router.use(authenticate, requireRoles(ROLES.DRIVER, ROLES.ADMIN));

router.get('/profile', c.getProfile);
router.get('/buses', c.listBuses);
router.post('/bus/assign', c.assignBus);
router.get('/trips', c.listTrips);
router.get('/live', c.live);
router.post('/trip/start', c.start);
router.post('/trip/pause', c.pause);
router.post('/trip/resume', c.resume);
router.post('/trip/end', c.end);
router.post('/stop/skip', c.skip);
router.post('/stop/reach', c.reach);

module.exports = router;
