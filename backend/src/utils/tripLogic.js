function canTransition(from, to, transitions) {
  return (transitions[from] || []).includes(to);
}

/**
 * Next valid route stop after currentSequence, skipping skipped sequences.
 * currentSequence 0 means trip just started (before first stop).
 */
function nextRouteStop(routeStops, currentSequence, skippedSequences = []) {
  const skipped = new Set(skippedSequences);
  const ordered = [...routeStops].sort((a, b) => a.sequence - b.sequence);
  return ordered.find((rs) => rs.sequence > currentSequence && !skipped.has(rs.sequence)) || null;
}

function remainingPhysicalStopIds(routeStops, currentSequence, skippedSequences = []) {
  const skipped = new Set(skippedSequences);
  return routeStops
    .filter((rs) => rs.sequence > currentSequence && !skipped.has(rs.sequence))
    .map((rs) => String(rs.stop._id || rs.stop));
}

function serializeRouteStop(rs) {
  if (!rs) return null;
  const stop = rs.stop && rs.stop.name ? rs.stop : null;
  return {
    id: String(rs._id),
    sequence: rs.sequence,
    latitude: rs.latitude,
    longitude: rs.longitude,
    stop: stop
      ? { id: String(stop._id), name: stop.name, code: stop.code, latitude: stop.latitude, longitude: stop.longitude }
      : { id: String(rs.stop) },
  };
}

module.exports = { canTransition, nextRouteStop, remainingPhysicalStopIds, serializeRouteStop };
