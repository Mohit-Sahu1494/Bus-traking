const { getRedis } = require('../config/redis');
const { env } = require('../config/env');
const { BUS_STATUS } = require('../utils/constants');

const keys = {
  location: (busId) => `bus:location:${busId}`,
  samples: (busId) => `bus:samples:${busId}`,
  heartbeat: (busId) => `bus:heartbeat:${busId}`,
  tripState: (tripId) => `trip:state:${tripId}`,
  waitingCount: (stopId) => `waiting:count:${stopId}`,
  arrival: (tripId, routeStopId) => `arrival:${tripId}:${routeStopId}`,
  notifDedup: (key) => `notif:dedup:${key}`,
};

async function setBusLocation(busId, payload) {
  const redis = getRedis();
  const json = JSON.stringify(payload);
  await redis.set(keys.location(busId), json, 'EX', env.busStaleTimeoutSec * 4);
  await redis.set(keys.heartbeat(busId), String(Date.now()), 'EX', env.busStaleTimeoutSec * 4);

  const sampleKey = keys.samples(busId);
  const samplesRaw = await redis.get(sampleKey);
  const samples = samplesRaw ? JSON.parse(samplesRaw) : [];
  samples.push({ latitude: payload.latitude, longitude: payload.longitude, at: payload.at, speed: payload.speed || 0 });
  const trimmed = samples.slice(-8);
  await redis.set(sampleKey, JSON.stringify(trimmed), 'EX', 300);
}

async function getBusLocation(busId) {
  const raw = await getRedis().get(keys.location(busId));
  return raw ? JSON.parse(raw) : null;
}

async function getSamples(busId) {
  const raw = await getRedis().get(keys.samples(busId));
  return raw ? JSON.parse(raw) : [];
}

async function setTripState(tripId, state) {
  await getRedis().set(keys.tripState(tripId), JSON.stringify(state), 'EX', 60 * 60 * 6);
}

async function getTripState(tripId) {
  const raw = await getRedis().get(keys.tripState(tripId));
  return raw ? JSON.parse(raw) : null;
}

async function clearTripState(tripId) {
  await getRedis().del(keys.tripState(tripId));
}

async function setWaitingCount(stopId, count) {
  await getRedis().set(keys.waitingCount(stopId), String(count), 'EX', 60 * 60 * 12);
}

async function getWaitingCount(stopId) {
  const raw = await getRedis().get(keys.waitingCount(stopId));
  return raw ? Number(raw) : 0;
}

async function setArrivalState(tripId, routeStopId, state) {
  await getRedis().set(keys.arrival(tripId, routeStopId), state, 'EX', 60 * 60 * 6);
}

async function getArrivalState(tripId, routeStopId) {
  return (await getRedis().get(keys.arrival(tripId, routeStopId))) || 'NONE';
}

async function claimNotification(dedupKey, ttlSec = 180) {
  const redis = getRedis();
  const key = keys.notifDedup(dedupKey);
  const existing = await redis.get(key);
  if (existing) return false;
  await redis.set(key, '1', 'EX', ttlSec);
  return true;
}

async function getHeartbeat(busId) {
  const raw = await getRedis().get(keys.heartbeat(busId));
  return raw ? Number(raw) : null;
}

module.exports = {
  keys,
  setBusLocation,
  getBusLocation,
  getSamples,
  setTripState,
  getTripState,
  clearTripState,
  setWaitingCount,
  getWaitingCount,
  setArrivalState,
  getArrivalState,
  claimNotification,
  getHeartbeat,
  BUS_STATUS,
};
