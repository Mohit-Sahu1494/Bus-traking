const { Driver, Bus, Route, Trip, TripStop, TripEvent, User } = require('../models');
const { AppError } = require('../utils/errors');
const {
  TRIP_STATUS,
  TRIP_TRANSITIONS,
  BUS_STATUS,
  SOCKET_EVENTS,
  TRIP_EVENT_TYPES,
} = require('../utils/constants');
const { canTransition, nextRouteStop } = require('../utils/tripLogic');
const { emitCampus } = require('../sockets/emitter');
const { setTripState, clearTripState, setBusLocation } = require('./realtimeStore');
const { loadRouteStops, tripProgress, studentsForPickup, remainingStopIds, getActiveTrip } = require('./routeService');
const { clearWaitingForStop, clearAllWaiting, waitingPayload } = require('./waitingService');
const { createAndPush } = require('./notificationService');

function assertTransition(from, to) {
  if (!canTransition(from, to, TRIP_TRANSITIONS)) {
    throw new AppError(`Cannot change trip from ${from} to ${to}.`, 400, 'INVALID_TRIP_STATE');
  }
}

async function assignedDriverContext(user) {
  const driver = await Driver.findOne({ user: user._id }).populate('assignedBus');
  if (!driver) {
    throw new AppError('Driver profile not found.', 404, 'DRIVER_NOT_FOUND');
  }
  if (!driver.assignedBus) {
    throw new AppError('No bus is assigned to this driver.', 400, 'NO_BUS_ASSIGNED');
  }
  return driver;
}

async function persistEvent(trip, type, extra = {}) {
  return TripEvent.create({
    trip: trip._id,
    type,
    stop: extra.stop,
    routeStop: extra.routeStop,
    metadata: extra.metadata || {},
  });
}

async function snapshot(trip) {
  const progress = await tripProgress(trip);
  const waiting = await waitingPayload();
  const allStops = await loadRouteStops(trip.route?._id || trip.route);
  const lastStop = allStops.length > 0 ? allStops[allStops.length - 1] : null;
  const isFinalStopReached = lastStop ? trip.completedSequences.includes(lastStop.sequence) : false;

  const state = {
    tripId: String(trip._id),
    status: trip.status,
    busId: String(trip.bus._id || trip.bus),
    busNumber: trip.bus.busNumber,
    busStatus:
      trip.status === TRIP_STATUS.PAUSED
        ? BUS_STATUS.PAUSED
        : trip.status === TRIP_STATUS.ACTIVE
          ? BUS_STATUS.ACTIVE
          : BUS_STATUS.INACTIVE,
    currentSequence: trip.currentSequence,
    skippedSequences: trip.skippedSequences,
    completedSequences: trip.completedSequences,
    isFinalStopReached,
    pauseReason: trip.pauseReason || null,
    startedAt: trip.startedAt,
    ...progress,
    waiting,
  };
  await setTripState(String(trip._id), state);
  return state;
}

function emitTrip(event, payload) {
  emitCampus(event, payload);
  emitCampus(SOCKET_EVENTS.BUS_STATUS_UPDATED, {
    busId: payload.busId,
    busNumber: payload.busNumber,
    status: payload.busStatus,
    tripStatus: payload.status,
  });
  if (payload.nextStop) {
    emitCampus(SOCKET_EVENTS.NEXT_STOP_UPDATED, {
      nextStop: payload.nextStop,
      currentStop: payload.currentStop,
      etaLabel: payload.etaLabel,
    });
  }
}

async function startTrip(user, initialCoords = null) {
  const driver = await assignedDriverContext(user);
  const existing = await Trip.findOne({
    driver: driver._id,
    status: { $in: [TRIP_STATUS.ACTIVE, TRIP_STATUS.PAUSED] },
  }).populate('bus').populate('route').populate('driver');

  if (existing) {
    if (
      initialCoords &&
      typeof initialCoords.latitude === 'number' &&
      typeof initialCoords.longitude === 'number' &&
      initialCoords.latitude >= -90 &&
      initialCoords.latitude <= 90 &&
      initialCoords.longitude >= -180 &&
      initialCoords.longitude <= 180
    ) {
      const locPayload = {
        latitude: initialCoords.latitude,
        longitude: initialCoords.longitude,
        speed: initialCoords.speed || 0,
        heading: initialCoords.heading || 0,
        accuracy: initialCoords.accuracy || null,
        at: new Date().toISOString(),
        busId: String(existing.bus._id),
        tripId: String(existing._id),
        status: existing.status,
      };
      await setBusLocation(String(existing.bus._id), locPayload);
      existing.bus.lastLocation = { latitude: locPayload.latitude, longitude: locPayload.longitude };
      existing.bus.lastLocationAt = new Date();
      existing.bus.lastHeartbeatAt = new Date();
      await existing.bus.save();
    }
    const state = await snapshot(existing);
    emitTrip(SOCKET_EVENTS.DRIVER_TRIP_STARTED, state);
    return state;
  }

  const bus = await Bus.findById(driver.assignedBus._id);
  if (bus.assignedDriver && String(bus.assignedDriver) !== String(driver._id)) {
    throw new AppError('This bus is assigned to another driver.', 403, 'BUS_NOT_YOURS');
  }

  const route = await Route.findOne({ isActive: true });
  if (!route) {
    throw new AppError('No active campus route is configured.', 500, 'NO_ROUTE');
  }

  const routeStops = await loadRouteStops(route._id);
  if (routeStops.length < 2) {
    throw new AppError('Campus route is incomplete.', 500, 'ROUTE_INCOMPLETE');
  }

  const trip = await Trip.create({
    driver: driver._id,
    bus: bus._id,
    route: route._id,
    status: TRIP_STATUS.ACTIVE,
    currentSequence: 0,
    startedAt: new Date(),
    completedSequences: [],
    skippedSequences: [],
  });

  await TripStop.insertMany(
    routeStops.map((rs, idx) => ({
      trip: trip._id,
      routeStop: rs._id,
      sequence: rs.sequence,
      status: idx === 0 ? 'CURRENT' : 'PENDING',
    }))
  );

  bus.status = BUS_STATUS.ACTIVE;
  bus.activeTrip = trip._id;
  bus.assignedDriver = driver._id;

  if (
    initialCoords &&
    typeof initialCoords.latitude === 'number' &&
    typeof initialCoords.longitude === 'number' &&
    initialCoords.latitude >= -90 &&
    initialCoords.latitude <= 90 &&
    initialCoords.longitude >= -180 &&
    initialCoords.longitude <= 180
  ) {
    const locPayload = {
      latitude: initialCoords.latitude,
      longitude: initialCoords.longitude,
      speed: initialCoords.speed || 0,
      heading: initialCoords.heading || 0,
      accuracy: initialCoords.accuracy || null,
      at: new Date().toISOString(),
      busId: String(bus._id),
      tripId: String(trip._id),
      status: TRIP_STATUS.ACTIVE,
    };
    await setBusLocation(String(bus._id), locPayload);
    bus.lastLocation = { latitude: locPayload.latitude, longitude: locPayload.longitude };
    bus.lastLocationAt = new Date();
    bus.lastHeartbeatAt = new Date();
  }

  await bus.save();

  const populated = await Trip.findById(trip._id).populate('bus').populate('route').populate('driver');
  await persistEvent(populated, TRIP_EVENT_TYPES.STARTED);
  const state = await snapshot(populated);
  emitTrip(SOCKET_EVENTS.DRIVER_TRIP_STARTED, state);
  emitCampus(SOCKET_EVENTS.ROUTE_UPDATED, { routeStops: state.routeStops });

  // Asynchronous non-blocking push notification dispatch
  User.find({ role: 'STUDENT' })
    .select('_id')
    .then((students) => {
      if (!students.length) return;
      return createAndPush({
        userIds: students.map((s) => s._id),
        title: `${bus.busNumber} is active`,
        body: 'Campus bus trip has started. Track it live on the map.',
        type: 'TRIP_STARTED',
        data: { tripId: String(trip._id), busNumber: bus.busNumber },
        trip: trip._id,
        dedupKey: `trip-start-${trip._id}`,
      });
    })
    .catch((err) => {
      console.error('Background trip start notification failed:', err.message);
    });

  return state;
}

async function pauseTrip(user, reason) {
  const driver = await assignedDriverContext(user);
  const trip = await Trip.findOne({
    driver: driver._id,
    status: TRIP_STATUS.ACTIVE,
  }).populate('bus');
  if (!trip) throw new AppError('No active trip to pause.', 400, 'NO_ACTIVE_TRIP');

  assertTransition(trip.status, TRIP_STATUS.PAUSED);
  trip.status = TRIP_STATUS.PAUSED;
  trip.pauseReason = reason;
  await trip.save();

  trip.bus.status = BUS_STATUS.PAUSED;
  await trip.bus.save();

  await persistEvent(trip, TRIP_EVENT_TYPES.PAUSED, { metadata: { reason } });
  const state = await snapshot(trip);
  emitTrip(SOCKET_EVENTS.DRIVER_TRIP_PAUSED, state);

  const students = await User.find({ role: 'STUDENT' }).select('_id');
  await createAndPush({
    userIds: students.map((s) => s._id),
    title: '⏸ Bus paused',
    body: `${trip.bus.busNumber} has temporarily paused its trip.${reason ? ` (${reason})` : ''}`,
    type: 'TRIP_PAUSED',
    data: { reason: reason || '', tripId: String(trip._id) },
    trip: trip._id,
    settingKey: 'paused',
    dedupKey: `pause-${trip._id}-${Math.floor(Date.now() / 60000)}`,
  });

  return state;
}

async function resumeTrip(user) {
  const driver = await assignedDriverContext(user);
  const trip = await Trip.findOne({
    driver: driver._id,
    status: TRIP_STATUS.PAUSED,
  }).populate('bus');
  if (!trip) throw new AppError('No paused trip to resume.', 400, 'NO_PAUSED_TRIP');

  assertTransition(trip.status, TRIP_STATUS.ACTIVE);
  trip.status = TRIP_STATUS.ACTIVE;
  trip.pauseReason = undefined;
  await trip.save();

  trip.bus.status = BUS_STATUS.ACTIVE;
  await trip.bus.save();

  await persistEvent(trip, TRIP_EVENT_TYPES.RESUMED);
  const state = await snapshot(trip);
  emitTrip(SOCKET_EVENTS.DRIVER_TRIP_RESUMED, state);

  const students = await User.find({ role: 'STUDENT' }).select('_id');
  await createAndPush({
    userIds: students.map((s) => s._id),
    title: '▶️ Bus resumed',
    body: `${trip.bus.busNumber} has resumed its trip.`,
    type: 'TRIP_RESUMED',
    data: { tripId: String(trip._id) },
    trip: trip._id,
    settingKey: 'paused',
    dedupKey: `resume-${trip._id}-${Math.floor(Date.now() / 60000)}`,
  });

  return state;
}

async function endTrip(user, cancelled = false) {
  const driver = await assignedDriverContext(user);
  const trip = await Trip.findOne({
    driver: driver._id,
    status: { $in: [TRIP_STATUS.ACTIVE, TRIP_STATUS.PAUSED] },
  }).populate('bus');
  if (!trip) throw new AppError('No active trip to end.', 400, 'NO_ACTIVE_TRIP');

  const nextStatus = cancelled ? TRIP_STATUS.CANCELLED : TRIP_STATUS.COMPLETED;
  if (trip.status === TRIP_STATUS.PAUSED && nextStatus === TRIP_STATUS.COMPLETED) {
    throw new AppError('Resume the trip before completing it, or cancel it.', 400, 'INVALID_TRIP_STATE');
  }
  assertTransition(trip.status, nextStatus);

  const now = new Date();
  trip.status = nextStatus;
  trip.endedAt = now;
  trip.durationMs = now.getTime() - new Date(trip.startedAt).getTime();
  await trip.save();

  trip.bus.status = BUS_STATUS.INACTIVE;
  trip.bus.activeTrip = undefined;
  await trip.bus.save();

  await persistEvent(trip, TRIP_EVENT_TYPES.ENDED, { metadata: { status: nextStatus } });
  await clearAllWaiting();
  await clearTripState(String(trip._id));

  const state = {
    tripId: String(trip._id),
    status: trip.status,
    busId: String(trip.bus._id),
    busNumber: trip.bus.busNumber,
    busStatus: BUS_STATUS.INACTIVE,
    endedAt: trip.endedAt,
    durationMs: trip.durationMs,
    completedSequences: trip.completedSequences,
    skippedSequences: trip.skippedSequences,
  };
  emitTrip(SOCKET_EVENTS.DRIVER_TRIP_ENDED, state);

  const students = await User.find({ role: 'STUDENT' }).select('_id');
  await createAndPush({
    userIds: students.map((s) => s._id),
    title: 'Trip ended',
    body: `${trip.bus.busNumber} has completed this trip.`,
    type: 'TRIP_ENDED',
    data: { tripId: String(trip._id) },
    trip: trip._id,
    settingKey: 'tripEnded',
    dedupKey: `end-${trip._id}`,
  });

  return state;
}

async function skipNextStop(user, routeStopId) {
  const driver = await assignedDriverContext(user);
  const trip = await Trip.findOne({
    driver: driver._id,
    status: TRIP_STATUS.ACTIVE,
  }).populate('bus');
  if (!trip) throw new AppError('Start a trip before skipping a stop.', 400, 'NO_ACTIVE_TRIP');

  const routeStops = await loadRouteStops(trip.route);
  const next = nextRouteStop(routeStops, trip.currentSequence, trip.skippedSequences);
  if (!next) {
    throw new AppError('There is no upcoming stop to skip.', 400, 'NO_NEXT_STOP');
  }
  if (routeStopId && String(next._id) !== String(routeStopId)) {
    throw new AppError('You can only skip the next stop.', 400, 'INVALID_STOP');
  }

  if (trip.skippedSequences.includes(next.sequence)) {
    throw new AppError('This stop is already skipped.', 400, 'STOP_ALREADY_SKIPPED');
  }

  trip.skippedSequences.push(next.sequence);
  await trip.save();

  await TripStop.findOneAndUpdate(
    { trip: trip._id, sequence: next.sequence },
    { status: 'SKIPPED', skippedAt: new Date() }
  );

  await persistEvent(trip, TRIP_EVENT_TYPES.STOP_SKIPPED, {
    stop: next.stop._id,
    routeStop: next._id,
    metadata: { sequence: next.sequence, name: next.stop.name },
  });

  const remaining = await remainingStopIds(trip);
  const stillOnRoute = remaining.includes(String(next.stop._id));
  if (!stillOnRoute) {
    await clearWaitingForStop(next.stop._id);
  }

  const state = await snapshot(trip);
  emitCampus(SOCKET_EVENTS.STOP_SKIPPED, {
    ...state,
    skippedStop: {
      id: String(next._id),
      name: next.stop.name,
      sequence: next.sequence,
    },
  });
  emitCampus(SOCKET_EVENTS.NEXT_STOP_UPDATED, {
    nextStop: state.nextStop,
    currentStop: state.currentStop,
    etaLabel: state.etaLabel,
  });

  const pickupStudents = await studentsForPickup(next.stop._id);
  await createAndPush({
    userIds: pickupStudents.map((s) => s._id),
    title: '⚠️ Stop skipped',
    body: `${next.stop.name} has been skipped by ${trip.bus.busNumber}.${state.nextStop ? ` Next stop: ${state.nextStop.stop.name}.` : ''}`,
    type: 'STOP_SKIPPED',
    data: {
      skippedStop: next.stop.name,
      nextStop: state.nextStop?.stop?.name || '',
      routeStopId: String(next._id),
      sequence: next.sequence,
    },
    trip: trip._id,
    settingKey: 'stopSkipped',
    dedupKey: `skip-${trip._id}-${next.sequence}`,
  });

  return state;
}

async function markStopReached(trip, routeStop) {
  if (trip.completedSequences.includes(routeStop.sequence)) return snapshot(trip);

  trip.completedSequences.push(routeStop.sequence);
  trip.currentSequence = routeStop.sequence;
  await trip.save();

  await TripStop.updateMany({ trip: trip._id, status: 'CURRENT' }, { status: 'PENDING' });
  await TripStop.findOneAndUpdate(
    { trip: trip._id, sequence: routeStop.sequence },
    { status: 'COMPLETED', arrivedAt: new Date() }
  );

  const next = nextRouteStop(await loadRouteStops(trip.route), trip.currentSequence, trip.skippedSequences);
  if (next) {
    await TripStop.findOneAndUpdate({ trip: trip._id, sequence: next.sequence }, { status: 'CURRENT' });
  }

  await persistEvent(trip, TRIP_EVENT_TYPES.STOP_REACHED, {
    stop: routeStop.stop._id || routeStop.stop,
    routeStop: routeStop._id,
    metadata: { sequence: routeStop.sequence, name: routeStop.stop.name },
  });

  await clearWaitingForStop(routeStop.stop._id || routeStop.stop);

  const populated = await Trip.findById(trip._id).populate('bus').populate('route');
  const state = await snapshot(populated);
  emitCampus(SOCKET_EVENTS.STOP_REACHED, {
    ...state,
    reachedStop: {
      id: String(routeStop._id),
      name: routeStop.stop.name,
      sequence: routeStop.sequence,
    },
    isFinalStopReached: state.isFinalStopReached,
  });

  emitCampus(SOCKET_EVENTS.NEXT_STOP_UPDATED, {
    nextStop: state.nextStop,
    currentStop: state.currentStop,
    etaLabel: state.etaLabel,
    isFinalStopReached: state.isFinalStopReached,
  });

  const pickupStudents = await studentsForPickup(routeStop.stop._id);
  await createAndPush({
    userIds: pickupStudents.map((s) => s._id),
    title: '📍 Bus arrived',
    body: `${populated.bus.busNumber} has reached ${routeStop.stop.name}.`,
    type: 'BUS_ARRIVED_STOP',
    data: {
      stopName: routeStop.stop.name,
      routeStopId: String(routeStop._id),
      sequence: routeStop.sequence,
    },
    trip: trip._id,
    settingKey: 'busArrived',
    dedupKey: `arrived-${trip._id}-${routeStop.sequence}`,
  });

  if (state.isFinalStopReached) {
    const driverRecord = await Driver.findById(trip.driver);
    const driverUser = driverRecord ? await User.findById(driverRecord.user) : null;
    if (driverUser) {
      await createAndPush({
        userIds: [driverUser._id],
        title: '🏁 Final Stop Reached',
        body: `You have reached the final stop (${routeStop.stop.name}). You can now confirm and end the trip.`,
        type: 'FINAL_STOP_REACHED',
        data: { tripId: String(trip._id) },
        trip: trip._id,
        dedupKey: `final-${trip._id}-${routeStop.sequence}`,
      });
    }
  }

  return state;
}

async function liveCampusState() {
  const trip = await getActiveTrip();
  if (!trip) {
    return {
      busStatus: BUS_STATUS.INACTIVE,
      trip: null,
      waiting: await waitingPayload(),
    };
  }
  const state = await snapshot(trip);
  return { busStatus: state.busStatus, trip: state, waiting: state.waiting };
}

async function driverLiveState(user) {
  const driver = await assignedDriverContext(user);
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const tripsToday = await Trip.find({
    driver: driver._id,
    startedAt: { $gte: todayStart },
  }).sort({ startedAt: -1 });

  const active = tripsToday.find((t) => [TRIP_STATUS.ACTIVE, TRIP_STATUS.PAUSED].includes(t.status));
  let live = null;
  if (active) {
    const populated = await Trip.findById(active._id).populate('bus').populate('route');
    live = await snapshot(populated);
  }

  return {
    bus: {
      id: String(driver.assignedBus._id),
      busNumber: driver.assignedBus.busNumber,
      status: driver.assignedBus.status,
    },
    live,
    tripsToday: tripsToday.length,
  };
}

module.exports = {
  startTrip,
  pauseTrip,
  resumeTrip,
  endTrip,
  skipNextStop,
  markStopReached,
  liveCampusState,
  driverLiveState,
  assignedDriverContext,
  snapshot,
};
