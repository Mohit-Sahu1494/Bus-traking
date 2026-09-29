const mongoose = require('mongoose');
const { ROLES } = require('../utils/constants');

const userSchema = new mongoose.Schema(
  {
    role: { type: String, enum: Object.values(ROLES), required: true, index: true },
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    enrollmentNumber: { type: String, trim: true, sparse: true, unique: true },
    passwordHash: { type: String, required: true, select: false },
    pickupStop: { type: mongoose.Schema.Types.ObjectId, ref: 'Stop' },
    fcmToken: { type: String, default: '' },
    isEmailVerified: { type: Boolean, default: false },
    otpHash: { type: String, select: false },
    otpExpiresAt: { type: Date, select: false },
    otpAttempts: { type: Number, default: 0, select: false },
    otpLastSentAt: { type: Date, select: false },
    resetPasswordOtpHash: { type: String, select: false },
    resetPasswordOtpExpiresAt: { type: Date, select: false },
    resetPasswordOtpAttempts: { type: Number, default: 0, select: false },
    resetPasswordOtpLastSentAt: { type: Date, select: false },
    notificationSettings: {
      busApproaching: { type: Boolean, default: true },
      busArrived: { type: Boolean, default: true },
      stopSkipped: { type: Boolean, default: true },
      tripEnded: { type: Boolean, default: true },
      paused: { type: Boolean, default: true },
    },
  },
  { timestamps: true }
);

userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id,
    role: this.role,
    name: this.name,
    email: this.email,
    enrollmentNumber: this.enrollmentNumber || null,
    isEmailVerified: Boolean(this.isEmailVerified),
    pickupStop: this.pickupStop || null,
    notificationSettings: this.notificationSettings,
  };
};

module.exports = mongoose.model('User', userSchema);
