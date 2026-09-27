const { WaitingStatus, Stop, User } = require('../models');
const { SOCKET_EVENTS } = require('../utils/constants');
const { emitCampus } = require('../sockets/emitter');
const { setWaitingCount } = require('./realtimeStore');
const { AppError } = require('../utils/errors');

async function countsByStop() {
  const rows = await WaitingStatus.aggregate([
    { $match: { isActive: true } },
    { $group: { _id: '$stop', count: { $sum: 1 } } },
  ]);
  const map = {};
  for (const row of rows) {
    map[String(row._id)] = row.count;
    await setWaitingCount(String(row._id), row.count);
  }
  return map;
}

async function pickupCountsByStop() {
  const rows = await User.aggregate([
    { $match: { role: 'STUDENT', pickupStop: { $exists: true, $ne: null } } },
    { $group: { _id: '$pickupStop', count: { $sum: 1 } } },
  ]);
  const map = {};
  for (const row of rows) {
    map[String(row._id)] = row.count;
  }
  return map;
}

async function waitingPayload() {
  const stops = await Stop.find().lean();
  const counts = await countsByStop();
  const pickupCounts = await pickupCountsByStop();
  return stops.map((s) => ({
    stopId: String(s._id),
    name: s.name,
    code: s.code,
    studentsWaiting: counts[String(s._id)] || 0,
    studentsSelected: pickupCounts[String(s._id)] || 0,
  }));
}

async function emitWaitingUpdated() {
  const payload = await waitingPayload();
  emitCampus(SOCKET_EVENTS.STUDENT_WAITING_UPDATED, { stops: payload });
  return payload;
}

async function startWaiting(student) {
  if (!student.pickupStop) {
    throw new AppError('Select a pickup stop before waiting.', 400, 'NO_PICKUP_STOP');
  }

  await WaitingStatus.updateMany(
    { student: student._id, isActive: true },
    { $set: { isActive: false, endedAt: new Date() } }
  );

  await WaitingStatus.create({
    student: student._id,
    stop: student.pickupStop,
    isActive: true,
    startedAt: new Date(),
  });

  return emitWaitingUpdated();
}

async function cancelWaiting(student) {
  await WaitingStatus.updateMany(
    { student: student._id, isActive: true },
    { $set: { isActive: false, endedAt: new Date() } }
  );
  return emitWaitingUpdated();
}

async function clearWaitingForStop(stopId) {
  await WaitingStatus.updateMany(
    { stop: stopId, isActive: true },
    { $set: { isActive: false, endedAt: new Date() } }
  );
  return emitWaitingUpdated();
}

async function clearAllWaiting() {
  await WaitingStatus.updateMany(
    { isActive: true },
    { $set: { isActive: false, endedAt: new Date() } }
  );
  return emitWaitingUpdated();
}

async function studentIsWaiting(studentId) {
  return WaitingStatus.exists({ student: studentId, isActive: true });
}

module.exports = {
  countsByStop,
  waitingPayload,
  emitWaitingUpdated,
  startWaiting,
  cancelWaiting,
  clearWaitingForStop,
  clearAllWaiting,
  studentIsWaiting,
};
