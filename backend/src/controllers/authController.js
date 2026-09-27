const { asyncHandler } = require('../utils/errors');
const {
  parse,
  studentRegisterSchema,
  verifyOtpSchema,
  resendOtpSchema,
  loginSchema,
} = require('../validators');
const {
  registerStudent,
  verifyStudentOtp,
  resendStudentOtp,
  loginByRole,
} = require('../services/authService');
const { ROLES } = require('../utils/constants');

const studentRegister = asyncHandler(async (req, res) => {
  const body = parse(studentRegisterSchema, req.body);
  const result = await registerStudent(body);
  res.status(201).json({
    success: true,
    message: 'Verification code sent successfully',
    data: {
      email: result.email,
      unmaskedEmail: result.unmaskedEmail,
      pendingVerification: true,
    },
  });
});

const studentVerifyOtp = asyncHandler(async (req, res) => {
  const body = parse(verifyOtpSchema, req.body);
  const result = await verifyStudentOtp(body);
  res.json({
    success: true,
    message: 'Email verified successfully',
    data: {
      verified: true,
      token: result.token,
      user: result.user,
    },
  });
});

const studentResendOtp = asyncHandler(async (req, res) => {
  const body = parse(resendOtpSchema, req.body);
  const result = await resendStudentOtp(body);
  res.json({
    success: true,
    message: 'Verification code resent successfully',
    data: {
      email: result.email,
    },
  });
});

const studentLogin = asyncHandler(async (req, res) => {
  const body = parse(loginSchema, req.body);
  const result = await loginByRole(body, ROLES.STUDENT);
  res.json({
    success: true,
    message: 'Login successful',
    data: result,
  });
});

const driverLogin = asyncHandler(async (req, res) => {
  const body = parse(loginSchema, req.body);
  const result = await loginByRole(body, ROLES.DRIVER);
  res.json({
    success: true,
    message: 'Login successful',
    data: result,
  });
});

module.exports = {
  studentRegister,
  studentVerifyOtp,
  studentResendOtp,
  studentLogin,
  driverLogin,
};
