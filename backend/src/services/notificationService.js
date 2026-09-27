const { getMessaging } = require('../config/firebase');
const { Notification, User, DeviceToken } = require('../models');
const { SOCKET_EVENTS } = require('../utils/constants');
const { emitUser, emitCampus } = require('../sockets/emitter');
const { claimNotification } = require('./realtimeStore');

/**
 * Register or update an FCM device token for a user.
 * Supports multiple active devices per user.
 */
async function registerDeviceToken(userId, token, platform = 'android', deviceInfo = '') {
  if (!token || typeof token !== 'string') return null;
  const trimmed = token.trim();
  if (!trimmed) return null;

  try {
    const doc = await DeviceToken.findOneAndUpdate(
      { token: trimmed },
      {
        user: userId,
        platform,
        deviceInfo,
        isActive: true,
        lastSeenAt: new Date(),
      },
      { upsert: true, new: true }
    );

    // Keep User.fcmToken populated for backwards compatibility
    await User.findByIdAndUpdate(userId, { fcmToken: trimmed });
    return doc;
  } catch (err) {
    console.error('Failed to register device token:', err.message);
    return null;
  }
}

/**
 * Deactivate a device token on logout.
 */
async function deactivateDeviceToken(userId, token) {
  if (!token) return;
  try {
    await DeviceToken.updateMany(
      { user: userId, token: token.trim() },
      { isActive: false }
    );
  } catch (err) {
    console.error('Failed to deactivate device token:', err.message);
  }
}

/**
 * Prune invalid or expired tokens reported by FCM.
 */
async function pruneInvalidTokens(tokens, responses) {
  const invalidTokens = [];
  responses.forEach((resp, idx) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    try {
      await DeviceToken.updateMany(
        { token: { $in: invalidTokens } },
        { isActive: false }
      );
      await User.updateMany(
        { fcmToken: { $in: invalidTokens } },
        { fcmToken: '' }
      );
      console.log(`Pruned ${invalidTokens.length} inactive FCM token(s)`);
    } catch (err) {
      console.error('Failed to prune invalid tokens:', err.message);
    }
  }
}

/**
 * Centralized, isolated notification dispatcher.
 * Handles deduplication, multi-device delivery, in-app sockets, and FCM push notifications.
 * GUARANTEE: Never throws or breaks core trip/GPS processing.
 */
async function createAndPush({
  userIds,
  title,
  body,
  type,
  data = {},
  trip = null,
  dedupKey = null,
  settingKey = null,
}) {
  try {
    if (!userIds || userIds.length === 0) return [];

    // 1. In-memory / Redis atomic deduplication
    if (dedupKey) {
      const ok = await claimNotification(dedupKey, 3600); // 1-hour TTL
      if (!ok) return [];
    }

    // 2. Fetch users and filter by notification settings
    const users = await User.find({ _id: { $in: userIds } });
    if (!users.length) return [];

    const eligibleUsers = [];
    const eligibleUserIds = [];

    for (const user of users) {
      if (
        settingKey &&
        user.notificationSettings &&
        user.notificationSettings[settingKey] === false
      ) {
        continue;
      }
      eligibleUsers.push(user);
      eligibleUserIds.push(user._id);
    }

    if (!eligibleUsers.length) return [];

    // 3. Persist notifications & emit in-app Socket.IO events
    const createdDocs = [];
    const tripIdStr = trip ? String(trip._id || trip) : '';

    for (const user of eligibleUsers) {
      // DB-level deduplication check if dedupKey provided
      if (dedupKey) {
        const existing = await Notification.findOne({
          user: user._id,
          dedupKey,
        });
        if (existing) continue;
      }

      const doc = await Notification.create({
        user: user._id,
        title,
        body,
        type,
        data,
        trip: trip?._id || trip,
        dedupKey: dedupKey || undefined,
      });
      createdDocs.push(doc);

      // Real-time in-app notification event for open app
      emitUser(String(user._id), SOCKET_EVENTS.NOTIFICATION_CREATED, {
        id: String(doc._id),
        title,
        body,
        type,
        data,
        tripId: tripIdStr,
        createdAt: doc.createdAt,
      });
    }

    // 4. Emit campus-wide event for live counters
    emitCampus(SOCKET_EVENTS.NOTIFICATION_CREATED, {
      type,
      title,
      body,
      data: { ...data, tripId: tripIdStr },
    });

    // 5. Gather multi-device active FCM tokens
    const deviceTokens = await DeviceToken.find({
      user: { $in: eligibleUserIds },
      isActive: true,
    }).select('token');

    const tokenSet = new Set(deviceTokens.map((d) => d.token));
    for (const user of eligibleUsers) {
      if (user.fcmToken && user.fcmToken.trim()) {
        tokenSet.add(user.fcmToken.trim());
      }
    }

    const tokens = Array.from(tokenSet);

    // 6. Dispatch FCM Push Notification (runs safely in background)
    const messaging = getMessaging();
    if (messaging && tokens.length > 0) {
      const stringData = Object.fromEntries(
        Object.entries({
          type,
          title,
          body,
          tripId: tripIdStr,
          ...data,
        }).map(([k, v]) => [k, String(v ?? '')])
      );

      // Async dispatch without blocking caller
      messaging
        .sendEachForMulticast({
          tokens,
          notification: {
            title,
            body,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'campus_bus_alerts',
              icon: 'ic_launcher',
              sound: 'default',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          data: stringData,
        })
        .then((response) => {
          if (response.failureCount > 0) {
            pruneInvalidTokens(tokens, response.responses).catch(() => {});
          }
        })
        .catch((err) => {
          console.error('FCM multicast dispatch failed:', err.message);
        });
    }

    return createdDocs;
  } catch (err) {
    console.error('createAndPush notification failed:', err.message);
    return [];
  }
}

module.exports = {
  createAndPush,
  registerDeviceToken,
  deactivateDeviceToken,
};
