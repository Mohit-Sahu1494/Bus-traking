const { z } = require('zod');
const { AppError } = require('../utils/errors');

function parse(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const details = {};
    for (const issue of result.error.issues) {
      const field = issue.path.join('.') || 'body';
      if (!details[field]) {
        details[field] = issue.message;
      }
    }
    const firstMsg = result.error.issues[0]?.message || 'Validation failed';
    throw new AppError(firstMsg, 400, 'VALIDATION_ERROR', details);
  }
  return result.data;
}

const studentRegisterSchema = z.object({
  name: z.string().min(2, 'Name is required'),
  enrollmentNumber: z.string().min(3, 'Enrollment number is required'),
  email: z.string().email('Valid email is required'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

const verifyOtpSchema = z.object({
  email: z.string().email('Valid email is required'),
  otp: z.string().length(6, 'Verification code must be 6 digits').regex(/^\d{6}$/, 'Verification code must be numeric'),
});

const resendOtpSchema = z.object({
  email: z.string().email('Valid email is required'),
});

const loginSchema = z.object({
  email: z.string().email('Valid email is required'),
  password: z.string().min(1, 'Password is required'),
});

const pickupStopSchema = z.object({
  stopId: z.string().min(1, 'Stop is required'),
});

const pauseTripSchema = z.object({
  reason: z.enum(['TRAFFIC', 'TEMPORARY_ISSUE', 'BREAKDOWN', 'OPERATIONAL_PAUSE']),
});

const skipStopSchema = z.object({
  routeStopId: z.string().optional(),
});

const locationSchema = z.object({
  latitude: z.number().gte(-90).lte(90),
  longitude: z.number().gte(-180).lte(180),
  accuracy: z.number().optional(),
  speed: z.number().optional(),
  heading: z.number().optional(),
  timestamp: z.union([z.string(), z.number()]).optional(),
});

const fcmTokenSchema = z.object({
  token: z.string().min(10, 'FCM token is required'),
});

const notificationSettingsSchema = z.object({
  busApproaching: z.boolean().optional(),
  busArrived: z.boolean().optional(),
  stopSkipped: z.boolean().optional(),
  tripEnded: z.boolean().optional(),
  paused: z.boolean().optional(),
});

const profilePatchSchema = z.object({
  name: z.string().min(2).optional(),
  notificationSettings: notificationSettingsSchema.optional(),
});

module.exports = {
  parse,
  studentRegisterSchema,
  verifyOtpSchema,
  resendOtpSchema,
  loginSchema,
  pickupStopSchema,
  pauseTripSchema,
  skipStopSchema,
  locationSchema,
  fcmTokenSchema,
  profilePatchSchema,
};
