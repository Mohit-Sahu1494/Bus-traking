const express = require('express');
const { authenticate, requireRoles } = require('../middleware/auth');
const { ROLES } = require('../utils/constants');
const c = require('../controllers/studentController');

const router = express.Router();
router.use(authenticate, requireRoles(ROLES.STUDENT, ROLES.ADMIN));

router.get('/profile', c.getProfile);
router.patch('/profile', c.patchProfile);
router.patch('/pickup-stop', c.updatePickup);
router.post('/waiting', c.startWait);
router.delete('/waiting', c.stopWait);
router.get('/live', c.live);
router.post('/fcm-token', c.saveFcm);
router.delete('/fcm-token', c.removeFcm);

module.exports = router;
