const { User } = require('../models');
const { asyncHandler } = require('../utils/errors');
const { parse, pickupStopSchema, profilePatchSchema, fcmTokenSchema } = require('../validators');
const { setPickupStop } = require('../services/authService');
const { startWaiting, cancelWaiting, studentIsWaiting, waitingPayload } = require('../services/waitingService');
const { liveCampusState } = require('../services/tripService');
const { Notification } = require('../models');

const getProfile = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id).populate('pickupStop');
  res.json({
    success: true,
    message: 'Profile retrieved successfully',
    data: user.toPublicJSON(),
  });
});

const patchProfile = asyncHandler(async (req, res) => {
  const body = parse(profilePatchSchema, req.body);
  if (body.name) req.user.name = body.name;
  if (body.notificationSettings) {
    req.user.notificationSettings = {
      ...(req.user.notificationSettings.toObject?.() || req.user.notificationSettings),
      ...body.notificationSettings,
    };
  }
  await req.user.save();
  const user = await User.findById(req.user._id).populate('pickupStop');
  res.json({
    success: true,
    message: 'Profile updated successfully',
    data: user.toPublicJSON(),
  });
});

const updatePickup = asyncHandler(async (req, res) => {
  const { stopId } = parse(pickupStopSchema, req.body);
  const stop = await setPickupStop(req.user, stopId);
  await cancelWaiting(req.user);
  res.json({
    success: true,
    message: 'Pickup stop updated successfully',
    data: { pickupStop: { id: String(stop._id), name: stop.name, code: stop.code } },
  });
});

const startWait = asyncHandler(async (req, res) => {
  const waiting = await startWaiting(req.user);
  res.json({
    success: true,
    message: 'Waiting status updated',
    data: { waiting: true, stops: waiting },
  });
});

const stopWait = asyncHandler(async (req, res) => {
  const waiting = await cancelWaiting(req.user);
  res.json({
    success: true,
    message: 'Waiting status cancelled',
    data: { waiting: false, stops: waiting },
  });
});

const live = asyncHandler(async (req, res) => {
  const state = await liveCampusState();
  const isWaiting = Boolean(await studentIsWaiting(req.user._id));
  const counts = await waitingPayload();
  res.json({
    success: true,
    message: 'Campus live state retrieved successfully',
    data: { ...state, isWaiting, waiting: counts },
  });
});

const saveFcm = asyncHandler(async (req, res) => {
  const { token } = parse(fcmTokenSchema, req.body);
  const { registerDeviceToken } = require('../services/notificationService');
  await registerDeviceToken(
    req.user._id,
    token,
    req.body.platform || 'android',
    req.body.deviceInfo || ''
  );
  res.json({
    success: true,
    message: 'Notification token updated',
    data: { saved: true },
  });
});

const removeFcm = asyncHandler(async (req, res) => {
  const { deactivateDeviceToken } = require('../services/notificationService');
  const token = req.body?.token || req.query?.token || req.user.fcmToken;
  if (token) {
    await deactivateDeviceToken(req.user._id, token);
  }
  res.json({
    success: true,
    message: 'Notification token deactivated',
    data: { removed: true },
  });
});

const listNotifications = asyncHandler(async (req, res) => {
  const items = await Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50);
  res.json({
    success: true,
    message: 'Notifications retrieved successfully',
    data: items,
  });
});

const readNotification = asyncHandler(async (req, res) => {
  const item = await Notification.findOneAndUpdate(
    { _id: req.params.id, user: req.user._id },
    { readAt: new Date() },
    { new: true }
  );
  if (!item) {
    const { AppError } = require('../utils/errors');
    throw new AppError('Notification not found', 404, 'NOT_FOUND');
  }
  res.json({
    success: true,
    message: 'Notification marked as read',
    data: item,
  });
});

module.exports = {
  getProfile,
  patchProfile,
  updatePickup,
  startWait,
  stopWait,
  live,
  saveFcm,
  removeFcm,
  listNotifications,
  readNotification,
};
