function toRad(value) {
  return (value * Math.PI) / 180;
}

function haversineMeters(a, b) {
  const R = 6371000;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function speedMps(from, to, fromAt, toAt) {
  const dt = (new Date(toAt).getTime() - new Date(fromAt).getTime()) / 1000;
  if (dt <= 0) return 0;
  return haversineMeters(from, to) / dt;
}

function etaSeconds(distanceM, speedMpsValue) {
  if (!Number.isFinite(distanceM) || distanceM < 0) return null;
  if (!Number.isFinite(speedMpsValue) || speedMpsValue < 0.5) return null;
  return Math.round(distanceM / speedMpsValue);
}

module.exports = { haversineMeters, speedMps, etaSeconds };
