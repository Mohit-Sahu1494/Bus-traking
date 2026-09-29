const crypto = require('crypto');
const bcrypt = require('bcrypt');
const { User, Driver, StudentStopSelection } = require('../models');
const { ROLES } = require('../utils/constants');
const { signToken } = require('../utils/jwt');
const { AppError } = require('../utils/errors');
const { sendOtpEmail, maskEmail } = require('./emailService');

function generateSecureOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

async function registerStudent({ name, enrollmentNumber, email, password }) {
  const normEmail = email.toLowerCase().trim();
  const normEnrollment = enrollmentNumber ? enrollmentNumber.trim() : null;

  const existingUser = await User.findOne({ email: normEmail });
  if (existingUser) {
    if (existingUser.isEmailVerified) {
      throw new AppError('An account with this email already exists.', 409, 'ACCOUNT_EXISTS');
    }
    // Account exists but is unverified: update details and issue new OTP
    const passwordHash = await bcrypt.hash(password, 12);
    existingUser.name = name;
    if (normEnrollment) existingUser.enrollmentNumber = normEnrollment;
    existingUser.passwordHash = passwordHash;

    const otp = generateSecureOtp();
    existingUser.otpHash = await bcrypt.hash(otp, 10);
    existingUser.otpExpiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes
    existingUser.otpAttempts = 0;
    existingUser.otpLastSentAt = new Date();
    await existingUser.save();

    try {
      await sendOtpEmail({ email: normEmail, name, otp });
    } catch (err) {
      console.error('[OTP_DELIVERY_FAILED]', err.message);
      throw new AppError('Unable to send verification email. Please try again.', 503, 'OTP_DELIVERY_FAILED');
    }

    return {
      email: maskEmail(normEmail),
      unmaskedEmail: normEmail,
      pendingVerification: true,
    };
  }

  // Check enrollment number if provided
  if (normEnrollment) {
    const existingEnrollment = await User.findOne({ enrollmentNumber: normEnrollment });
    if (existingEnrollment && existingEnrollment.isEmailVerified) {
      throw new AppError('An account with this enrollment number already exists.', 409, 'ENROLLMENT_EXISTS');
    }
    if (existingEnrollment && !existingEnrollment.isEmailVerified) {
      // Remove stale unverified account holding the enrollment number
      await User.deleteOne({ _id: existingEnrollment._id });
    }
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const otp = generateSecureOtp();
  const otpHash = await bcrypt.hash(otp, 10);
  const otpExpiresAt = new Date(Date.now() + 5 * 60 * 1000);

  const user = await User.create({
    role: ROLES.STUDENT,
    name,
    enrollmentNumber: normEnrollment || undefined,
    email: normEmail,
    passwordHash,
    isEmailVerified: false,
    otpHash,
    otpExpiresAt,
    otpAttempts: 0,
    otpLastSentAt: new Date(),
  });

  try {
    await sendOtpEmail({ email: normEmail, name, otp });
  } catch (err) {
    console.error('[OTP_DELIVERY_FAILED]', err.message);
    throw new AppError('Unable to send verification email. Please try again.', 503, 'OTP_DELIVERY_FAILED');
  }

  return {
    email: maskEmail(user.email),
    unmaskedEmail: user.email,
    pendingVerification: true,
  };
}

async function verifyStudentOtp({ email, otp }) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role: ROLES.STUDENT }).select(
    '+otpHash +otpExpiresAt +otpAttempts'
  );

  if (!user) {
    throw new AppError('No account found with this email.', 404, 'ACCOUNT_NOT_FOUND');
  }

  if (user.isEmailVerified) {
    const token = signToken({ sub: String(user._id), role: user.role });
    return { verified: true, token, user: user.toPublicJSON() };
  }

  if (!user.otpExpiresAt || user.otpExpiresAt < new Date()) {
    throw new AppError('Verification code has expired', 400, 'OTP_EXPIRED');
  }

  if ((user.otpAttempts || 0) >= 5) {
    throw new AppError('Too many failed verification attempts. Please request a new code.', 429, 'OTP_ATTEMPTS_EXCEEDED');
  }

  const isMatch = await bcrypt.compare(otp, user.otpHash || '');
  if (!isMatch) {
    user.otpAttempts = (user.otpAttempts || 0) + 1;
    await user.save();
    throw new AppError('Invalid verification code', 400, 'INVALID_OTP');
  }

  user.isEmailVerified = true;
  user.otpHash = undefined;
  user.otpExpiresAt = undefined;
  user.otpAttempts = 0;
  await user.save();

  const token = signToken({ sub: String(user._id), role: user.role });
  return { verified: true, token, user: user.toPublicJSON() };
}

async function resendStudentOtp({ email }) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role: ROLES.STUDENT }).select(
    '+otpLastSentAt +isEmailVerified'
  );

  if (!user) {
    throw new AppError('No account found with this email.', 404, 'ACCOUNT_NOT_FOUND');
  }

  if (user.isEmailVerified) {
    throw new AppError('This email is already verified. Please login.', 400, 'ALREADY_VERIFIED');
  }

  const now = Date.now();
  if (user.otpLastSentAt && now - user.otpLastSentAt.getTime() < 30000) {
    const remainingSec = Math.ceil((30000 - (now - user.otpLastSentAt.getTime())) / 1000);
    throw new AppError(`Please wait ${remainingSec}s before requesting a new code.`, 429, 'RESEND_COOLDOWN');
  }

  const otp = generateSecureOtp();
  user.otpHash = await bcrypt.hash(otp, 10);
  user.otpExpiresAt = new Date(now + 5 * 60 * 1000);
  user.otpAttempts = 0;
  user.otpLastSentAt = new Date();
  await user.save();

  try {
    await sendOtpEmail({ email: normEmail, name: user.name, otp });
  } catch (err) {
    console.error('[OTP_DELIVERY_FAILED]', err.message);
    throw new AppError('Unable to send verification email. Please try again.', 503, 'OTP_DELIVERY_FAILED');
  }

  return { email: maskEmail(normEmail) };
}

async function loginByRole({ email, password }, role) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role }).select('+passwordHash');
  if (!user) {
    throw new AppError('Invalid email or password.', 401, 'INVALID_CREDENTIALS');
  }
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    throw new AppError('Invalid email or password.', 401, 'INVALID_CREDENTIALS');
  }

  if (role === ROLES.STUDENT && !user.isEmailVerified) {
    throw new AppError(
      'Please verify your email address to continue.',
      403,
      'EMAIL_NOT_VERIFIED',
      { email: maskEmail(user.email), unverifiedEmail: user.email }
    );
  }

  const extra = {};
  if (role === ROLES.DRIVER) {
    const driver = await Driver.findOne({ user: user._id });
    extra.driverId = driver ? String(driver._id) : null;
  }
  const token = signToken({ sub: String(user._id), role: user.role, ...extra });
  return { token, user: user.toPublicJSON() };
}

async function setPickupStop(user, stopId) {
  const { Stop } = require('../models');
  const stop = await Stop.findById(stopId);
  if (!stop) throw new AppError('Pickup stop is not available.', 400, 'INVALID_STOP');

  user.pickupStop = stop._id;
  await user.save();
  await StudentStopSelection.findOneAndUpdate(
    { student: user._id },
    { stop: stop._id, selectedAt: new Date() },
    { upsert: true }
  );
  return stop;
}

async function forgotStudentPassword({ email }) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role: ROLES.STUDENT }).select(
    '+resetPasswordOtpLastSentAt'
  );

  if (!user) {
    throw new AppError('No student account found with this email.', 404, 'ACCOUNT_NOT_FOUND');
  }

  if (!user.isEmailVerified) {
    throw new AppError(
      'Your email address is not verified yet. Please verify your email first.',
      403,
      'EMAIL_NOT_VERIFIED',
      { email: maskEmail(normEmail), unverifiedEmail: normEmail }
    );
  }

  const now = Date.now();
  if (user.resetPasswordOtpLastSentAt && now - user.resetPasswordOtpLastSentAt.getTime() < 30000) {
    const remainingSec = Math.ceil((30000 - (now - user.resetPasswordOtpLastSentAt.getTime())) / 1000);
    throw new AppError(`Please wait ${remainingSec}s before requesting a new code.`, 429, 'RESEND_COOLDOWN');
  }

  const otp = generateSecureOtp();
  user.resetPasswordOtpHash = await bcrypt.hash(otp, 10);
  user.resetPasswordOtpExpiresAt = new Date(now + 5 * 60 * 1000);
  user.resetPasswordOtpAttempts = 0;
  user.resetPasswordOtpLastSentAt = new Date();
  await user.save();

  try {
    await sendOtpEmail({ email: normEmail, name: user.name, otp, purpose: 'RESET_PASSWORD' });
  } catch (err) {
    console.error('[OTP_DELIVERY_FAILED]', err.message);
    throw new AppError('Unable to send password reset email. Please try again.', 503, 'OTP_DELIVERY_FAILED');
  }

  return {
    email: maskEmail(normEmail),
    unmaskedEmail: normEmail,
  };
}

async function resendStudentResetOtp({ email }) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role: ROLES.STUDENT }).select(
    '+resetPasswordOtpLastSentAt'
  );

  if (!user) {
    throw new AppError('No student account found with this email.', 404, 'ACCOUNT_NOT_FOUND');
  }

  if (!user.isEmailVerified) {
    throw new AppError(
      'Your email address is not verified yet. Please verify your email first.',
      403,
      'EMAIL_NOT_VERIFIED',
      { email: maskEmail(normEmail), unverifiedEmail: normEmail }
    );
  }

  const now = Date.now();
  if (user.resetPasswordOtpLastSentAt && now - user.resetPasswordOtpLastSentAt.getTime() < 30000) {
    const remainingSec = Math.ceil((30000 - (now - user.resetPasswordOtpLastSentAt.getTime())) / 1000);
    throw new AppError(`Please wait ${remainingSec}s before requesting a new code.`, 429, 'RESEND_COOLDOWN');
  }

  const otp = generateSecureOtp();
  user.resetPasswordOtpHash = await bcrypt.hash(otp, 10);
  user.resetPasswordOtpExpiresAt = new Date(now + 5 * 60 * 1000);
  user.resetPasswordOtpAttempts = 0;
  user.resetPasswordOtpLastSentAt = new Date();
  await user.save();

  try {
    await sendOtpEmail({ email: normEmail, name: user.name, otp, purpose: 'RESET_PASSWORD' });
  } catch (err) {
    console.error('[OTP_DELIVERY_FAILED]', err.message);
    throw new AppError('Unable to send password reset email. Please try again.', 503, 'OTP_DELIVERY_FAILED');
  }

  return { email: maskEmail(normEmail) };
}

async function resetStudentPassword({ email, otp, password }) {
  const normEmail = email.toLowerCase().trim();
  const user = await User.findOne({ email: normEmail, role: ROLES.STUDENT }).select(
    '+resetPasswordOtpHash +resetPasswordOtpExpiresAt +resetPasswordOtpAttempts'
  );

  if (!user) {
    throw new AppError('No student account found with this email.', 404, 'ACCOUNT_NOT_FOUND');
  }

  if (!user.resetPasswordOtpExpiresAt || user.resetPasswordOtpExpiresAt < new Date()) {
    throw new AppError('Password reset code has expired. Please request a new code.', 400, 'OTP_EXPIRED');
  }

  if ((user.resetPasswordOtpAttempts || 0) >= 5) {
    throw new AppError('Too many failed attempts. Please request a new code.', 429, 'OTP_ATTEMPTS_EXCEEDED');
  }

  const isMatch = await bcrypt.compare(otp, user.resetPasswordOtpHash || '');
  if (!isMatch) {
    user.resetPasswordOtpAttempts = (user.resetPasswordOtpAttempts || 0) + 1;
    await user.save();
    throw new AppError('Invalid reset code', 400, 'INVALID_OTP');
  }

  const passwordHash = await bcrypt.hash(password, 12);
  user.passwordHash = passwordHash;
  user.resetPasswordOtpHash = undefined;
  user.resetPasswordOtpExpiresAt = undefined;
  user.resetPasswordOtpAttempts = 0;
  user.resetPasswordOtpLastSentAt = undefined;
  await user.save();

  return {
    success: true,
    message: 'Password reset successfully. Please login with your new password.',
  };
}

module.exports = {
  registerStudent,
  verifyStudentOtp,
  resendStudentOtp,
  forgotStudentPassword,
  resendStudentResetOtp,
  resetStudentPassword,
  loginByRole,
  setPickupStop,
};
