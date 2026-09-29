const test = require('node:test');
const assert = require('node:assert/strict');
const {
  parse,
  studentRegisterSchema,
  verifyOtpSchema,
  resendOtpSchema,
  studentForgotPasswordSchema,
  studentResetPasswordSchema,
  studentResendResetOtpSchema,
  loginSchema,
} = require('../validators');
const { maskEmail, sendOtpEmail } = require('../services/emailService');

test('Validator Schemas and Sanitization', async (t) => {
  await t.test('studentRegisterSchema requires 8+ char password and valid email', () => {
    assert.throws(
      () =>
        parse(studentRegisterSchema, {
          name: 'A',
          enrollmentNumber: '1',
          email: 'not-an-email',
          password: 'short',
        }),
      (err) => err.code === 'VALIDATION_ERROR' && err.details.email !== undefined
    );

    const valid = parse(studentRegisterSchema, {
      name: 'Mohit Sahu',
      enrollmentNumber: '2024CS001',
      email: 'student@dhsgu.ac.in',
      password: 'StrongPassword123',
    });
    assert.equal(valid.email, 'student@dhsgu.ac.in');
  });

  await t.test('verifyOtpSchema enforces 6-digit numeric OTP', () => {
    assert.throws(
      () =>
        parse(verifyOtpSchema, {
          email: 'student@dhsgu.ac.in',
          otp: '123',
        }),
      (err) => err.code === 'VALIDATION_ERROR'
    );

    assert.throws(
      () =>
        parse(verifyOtpSchema, {
          email: 'student@dhsgu.ac.in',
          otp: 'ABCDEF',
        }),
      (err) => err.code === 'VALIDATION_ERROR'
    );

    const valid = parse(verifyOtpSchema, {
      email: 'student@dhsgu.ac.in',
      otp: '123456',
    });
    assert.equal(valid.otp, '123456');
  });

  await t.test('studentForgotPasswordSchema validates student email', () => {
    assert.throws(
      () => parse(studentForgotPasswordSchema, { email: 'bad-email' }),
      (err) => err.code === 'VALIDATION_ERROR'
    );

    const valid = parse(studentForgotPasswordSchema, { email: 'student@dhsgu.ac.in' });
    assert.equal(valid.email, 'student@dhsgu.ac.in');
  });

  await t.test('studentResetPasswordSchema enforces 6-digit OTP and 8+ char password', () => {
    assert.throws(
      () =>
        parse(studentResetPasswordSchema, {
          email: 'student@dhsgu.ac.in',
          otp: '12',
          password: '123',
        }),
      (err) => err.code === 'VALIDATION_ERROR'
    );

    const valid = parse(studentResetPasswordSchema, {
      email: 'student@dhsgu.ac.in',
      otp: '654321',
      password: 'NewStrongPassword123',
    });
    assert.equal(valid.otp, '654321');
    assert.equal(valid.password, 'NewStrongPassword123');
  });

  await t.test('maskEmail hides sensitive parts of email', () => {
    assert.equal(maskEmail('mohitsahu@gmail.com'), 'mo****@gmail.com');
    assert.equal(maskEmail('ab@test.com'), 'a*@test.com');
    assert.equal(maskEmail(''), '');
  });

  await t.test('sendOtpEmail handles verification dispatch gracefully in dev/test environment', async () => {
    const result = await sendOtpEmail({
      email: 'test.student@dhsgu.ac.in',
      name: 'Test Student',
      otp: '654321',
      purpose: 'VERIFICATION',
    });
    assert.ok(result);
    assert.ok(result.messageId || result.status);
  });

  await t.test('sendOtpEmail handles reset password dispatch gracefully in dev/test environment', async () => {
    const result = await sendOtpEmail({
      email: 'test.student@dhsgu.ac.in',
      name: 'Test Student',
      otp: '112233',
      purpose: 'RESET_PASSWORD',
    });
    assert.ok(result);
    assert.ok(result.messageId || result.status);
  });
});

