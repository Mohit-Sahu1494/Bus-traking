const { env } = require('../config/env');
const { BUS_STATUS, SOCKET_EVENTS, TRIP_STATUS, TRIP_EVENT_TYPES } = require('../utils/constants');
const { haversineMeters } = require('../utils/geo');
const { Bus, Trip, User } = require('../models');
const { emitCampus } = require('../sockets/emitter');
const { setBusLocation, getArrivalState, setArrivalState } = require('./realtimeStore');
const { loadRouteStops } = require('./routeService');
const { nextRouteStop, serializeRouteStop } = require('../utils/tripLogic');
const { markStopReached, snapshot } = require('./tripService');
const { createAndPush } = require('./notificationService');
const { studentsForPickup } = require('./routeService');

let lastSamplePersist = new Map();

async function handleDriverLocation(driverUserId, coords) {
  const { Driver } = require('../models');
  const driver = await Driver.findOne({ user: driverUserId }).populate('assignedBus');
  if (!driver?.assignedBus) return null;

  const trip = await Trip.findOne({
    driver: driver._id,
    status: { $in: [TRIP_STATUS.ACTIVE, TRIP_STATUS.PAUSED] },
  }).populate('bus');
  if (!trip) return null;

  const payload = {
    latitude: coords.latitude,
    longitude: coords.longitude,
    speed: coords.speed || 0,
    heading: coords.heading || 0,
    accuracy: coords.accuracy || null,
    at: new Date().toISOString(),
    busId: String(trip.bus._id),
    tripId: String(trip._id),
    status: trip.status,
  };

  await setBusLocation(String(trip.bus._id), payload);

  trip.bus.lastLocation = { latitude: payload.latitude, longitude: payload.longitude };
  trip.bus.lastLocationAt = new Date();
  trip.bus.lastHeartbeatAt = new Date();
  if (trip.bus.status === BUS_STATUS.OFFLINE) {
    trip.bus.status = trip.status === TRIP_STATUS.PAUSED ? BUS_STATUS.PAUSED : BUS_STATUS.ACTIVE;
    emitCampus(SOCKET_EVENTS.BUS_STATUS_UPDATED, {
      busId: String(trip.bus._id),
      busNumber: trip.bus.busNumber,
      status: trip.bus.status,
      tripStatus: trip.status,
    });
  }
  await trip.bus.save();

  const routeStops = await loadRouteStops(trip.route);
  const next = nextRouteStop(routeStops, trip.currentSequence, trip.skippedSequences);
  const current =
    trip.currentSequence > 0
      ? routeStops.find((rs) => rs.sequence === trip.currentSequence) || null
      : null;

  let etaLabel = 'Calculating...';
  if (next) {
    const distM = haversineMeters(
      { latitude: payload.latitude, longitude: payload.longitude },
      { latitude: next.latitude, longitude: next.longitude }
    );
    payload.distanceM = distM;
    if (distM <= env.stopArrivalRadiusM) {
      etaLabel = 'Arriving now';
    } else if (distM <= env.stopApproachRadiusM) {
      etaLabel = `< 1 min (${Math.round(distM)}m)`;
    } else {
      const mins = Math.max(1, Math.round(distM / 300));
      etaLabel = `${mins} min`;
    }
  }

  payload.currentSequence = trip.currentSequence;
  payload.currentStop = serializeRouteStop(current);
  payload.nextStop = serializeRouteStop(next);
  payload.etaLabel = etaLabel;

  emitCampus(SOCKET_EVENTS.DRIVER_LOCATION_UPDATED, payload);

  if (trip.status === TRIP_STATUS.ACTIVE) {
    await detectArrival(trip, payload);
    await checkTripDelay(trip, payload, next);
  }

  const now = Date.now();
  const last = lastSamplePersist.get(String(trip._id)) || 0;
  if (now - last > 30000) {
    lastSamplePersist.set(String(trip._id), now);
    const { TripEvent } = require('../models');
    await TripEvent.create({
      trip: trip._id,
      type: TRIP_EVENT_TYPES.LOCATION_SAMPLE,
      metadata: { latitude: payload.latitude, longitude: payload.longitude },
    });
  }

  return payload;
}

async function detectArrival(trip, location) {
  // Accuracy check: reject stop triggers if accuracy is poor (> 50m error)
  if (location.accuracy != null && location.accuracy > 50) {
    return;
  }

  const routeStops = await loadRouteStops(trip.route);
  const next = nextRouteStop(routeStops, trip.currentSequence, trip.skippedSequences);
  if (!next) return;

  const distance = haversineMeters(location, { latitude: next.latitude, longitude: next.longitude });
  const prev = await getArrivalState(String(trip._id), String(next._id));

  if (distance <= env.stopArrivalRadiusM) {
    if (prev !== 'ARRIVED') {
      await setArrivalState(String(trip._id), String(next._id), 'ARRIVED');
      await markStopReached(trip, next);
    }
    return;
  }

  if (distance <= env.stopApproachRadiusM && prev === 'NONE') {
    await setArrivalState(String(trip._id), String(next._id), 'APPROACHING');
    const pickupStudents = await studentsForPickup(next.stop._id);
    await createAndPush({
      userIds: pickupStudents.map((s) => s._id),
      title: '🚌 Bus approaching',
      body: `${trip.bus.busNumber} is approaching your pickup stop, ${next.stop.name}.`,
      type: 'BUS_APPROACHING_STOP',
      data: {
        stopName: next.stop.name,
        routeStopId: String(next._id),
        sequence: next.sequence,
      },
      trip: trip._id,
      settingKey: 'busApproaching',
      dedupKey: `approach-${trip._id}-${next.sequence}`,
    });
    const state = await snapshot(trip);
    emitCampus(SOCKET_EVENTS.NEXT_STOP_UPDATED, {
      nextStop: state.nextStop,
      currentStop: state.currentStop,
      approaching: true,
      etaLabel: state.etaLabel,
    });
  }
}

async function checkTripDelay(trip, location, next) {
  if (!next || !trip.startedAt) return;
  const now = Date.now();
  const elapsedMinutes = (now - new Date(trip.startedAt).getTime()) / 60000;

  // If trip running for over 12 minutes and progress is stalled or delay threshold crossed
  if (elapsedMinutes >= 12 && trip.currentSequence <= 2) {
    const pickupStudents = await studentsForPickup(next.stop._id);
    createAndPush({
      userIds: pickupStudents.map((s) => s._id),
      title: '⏱ Bus delayed',
      body: `${trip.bus.busNumber} is currently delayed. Expected arrival may be later than usual.`,
      type: 'TRIP_DELAYED',
      data: {
        tripId: String(trip._id),
        nextStop: next.stop.name,
      },
      trip: trip._id,
      dedupKey: `delay-${trip._id}`,
    }).catch(() => {});
  }
}

async function startHeartbeatMonitor() {
  const intervalMs = Math.max(5000, (env.busStaleTimeoutSec * 1000) / 3);
  setInterval(async () => {
    try {
      const activeBuses = await Bus.find({
        status: { $in: [BUS_STATUS.ACTIVE, BUS_STATUS.PAUSED] },
      });
      const cutoff = Date.now() - env.busStaleTimeoutSec * 1000;
      for (const bus of activeBuses) {
        const last = bus.lastHeartbeatAt ? bus.lastHeartbeatAt.getTime() : 0;
        if (last && last < cutoff && bus.status !== BUS_STATUS.OFFLINE) {
          bus.status = BUS_STATUS.OFFLINE;
          await bus.save();
          emitCampus(SOCKET_EVENTS.BUS_STATUS_UPDATED, {
            busId: String(bus._id),
            busNumber: bus.busNumber,
            status: BUS_STATUS.OFFLINE,
          });
        }
      }
    } catch (err) {
      console.error('Heartbeat monitor:', err.message);
    }
  }, intervalMs).unref();
}

module.exports = { handleDriverLocation, startHeartbeatMonitor };
