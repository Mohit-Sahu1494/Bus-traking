const express = require('express');
const { authenticate } = require('../middleware/auth');
const catalog = require('../controllers/catalogController');
const student = require('../controllers/studentController');

const router = express.Router();
router.use(authenticate);

router.get('/buses', catalog.listBuses);
router.get('/buses/:id', catalog.getBus);
router.get('/routes', catalog.listRoutes);
router.get('/routes/:id', catalog.getRoute);
router.get('/stops', catalog.listStops);
router.get('/notifications', student.listNotifications);
router.patch('/notifications/:id/read', student.readNotification);

module.exports = router;
