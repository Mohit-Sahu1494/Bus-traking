const { RouteStop, User, Trip } = require('../models');
const { nextRouteStop, remainingPhysicalStopIds, serializeRouteStop } = require('../utils/tripLogic');
const { haversineMeters, etaSeconds } = require('../utils/geo');
const { getBusLocation, getSamples } = require('./realtimeStore');

async function loadRouteStops(routeId) {
  return RouteStop.find({ route: routeId }).populate('stop').sort({ sequence: 1 });
}

function averageSpeedMps(samples) {
  if (!samples || samples.length < 2) return 0;
  const last = samples[samples.length - 1];
  const prev = samples[0];
  const dist = haversineMeters(prev, last);
  const dt = (new Date(last.at).getTime() - new Date(prev.at).getTime()) / 1000;
  if (dt <= 0) return 0;
  return dist / dt;
}

async function tripProgress(trip) {
  const routeStops = await loadRouteStops(trip.route);
  const current =
    trip.currentSequence > 0
      ? routeStops.find((rs) => rs.sequence === trip.currentSequence) || null
      : null;
  const next = nextRouteStop(routeStops, trip.currentSequence, trip.skippedSequences);
  const location = await getBusLocation(String(trip.bus._id || trip.bus));
  const samples = await getSamples(String(trip.bus._id || trip.bus));

  let eta = null;
  let etaLabel = 'Calculating...';
  if (location && next) {
    const distanceM = haversineMeters(location, { latitude: next.latitude, longitude: next.longitude });
    const speed = location.speed > 0.5 ? location.speed : averageSpeedMps(samples);
    const seconds = etaSeconds(distanceM, speed);
    if (seconds != null) {
      eta = Math.max(1, Math.round(seconds / 60));
      etaLabel = `${eta} min`;
    }
  }

  return {
    routeStops: routeStops.map(serializeRouteStop),
    currentStop: serializeRouteStop(current),
    nextStop: serializeRouteStop(next),
    location,
    etaMinutes: eta,
    etaLabel,
  };
}

async function studentsForPickup(stopId) {
  return User.find({ role: 'STUDENT', pickupStop: stopId }).select('_id fcmToken notificationSettings');
}

async function remainingStopIds(trip) {
  const routeStops = await loadRouteStops(trip.route);
  return remainingPhysicalStopIds(routeStops, trip.currentSequence, trip.skippedSequences);
}

async function getActiveTrip() {
  return Trip.findOne({ status: { $in: ['ACTIVE', 'PAUSED'] } })
    .populate('driver')
    .populate('bus')
    .populate('route');
}

module.exports = {
  loadRouteStops,
  tripProgress,
  studentsForPickup,
  remainingStopIds,
  getActiveTrip,
};
