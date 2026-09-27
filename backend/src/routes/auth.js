const express = require('express');
const {
  studentRegister,
  studentVerifyOtp,
  studentResendOtp,
  studentLogin,
  driverLogin,
} = require('../controllers/authController');

const router = express.Router();
router.post('/student/register', studentRegister);
router.post('/student/verify-otp', studentVerifyOtp);
router.post('/student/resend-otp', studentResendOtp);
router.post('/student/login', studentLogin);
router.post('/driver/login', driverLogin);

module.exports = router;
