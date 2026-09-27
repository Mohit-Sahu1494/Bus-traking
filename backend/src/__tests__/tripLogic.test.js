const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { nextRouteStop, canTransition } = require('../utils/tripLogic');
const { TRIP_STATUS, TRIP_TRANSITIONS } = require('../utils/constants');

const route = [
  { sequence: 1, stop: { name: 'Center Point' } },
  { sequence: 2, stop: { name: 'Computer Science Department' } },
  { sequence: 3, stop: { name: 'Criminology Department' } },
  { sequence: 4, stop: { name: 'Center Point' } },
  { sequence: 5, stop: { name: 'Boys Hostel' } },
  { sequence: 6, stop: { name: 'Girls Hostel' } },
  { sequence: 7, stop: { name: 'Center Point' } },
];

describe('next stop calculation', () => {
  it('starts at sequence 1', () => {
    assert.equal(nextRouteStop(route, 0, []).sequence, 1);
  });

  it('advances past current sequence', () => {
    assert.equal(nextRouteStop(route, 3, []).stop.name, 'Center Point');
    assert.equal(nextRouteStop(route, 3, []).sequence, 4);
  });

  it('skips skipped sequences', () => {
    const next = nextRouteStop(route, 4, [5]);
    assert.equal(next.sequence, 6);
    assert.equal(next.stop.name, 'Girls Hostel');
  });

  it('returns null after final stop', () => {
    assert.equal(nextRouteStop(route, 7, []), null);
  });
});

describe('trip state machine', () => {
  it('allows start, pause, resume, complete', () => {
    assert.equal(canTransition(TRIP_STATUS.NOT_STARTED, TRIP_STATUS.ACTIVE, TRIP_TRANSITIONS), true);
    assert.equal(canTransition(TRIP_STATUS.ACTIVE, TRIP_STATUS.PAUSED, TRIP_TRANSITIONS), true);
    assert.equal(canTransition(TRIP_STATUS.PAUSED, TRIP_STATUS.ACTIVE, TRIP_TRANSITIONS), true);
    assert.equal(canTransition(TRIP_STATUS.ACTIVE, TRIP_STATUS.COMPLETED, TRIP_TRANSITIONS), true);
  });

  it('rejects invalid transitions', () => {
    assert.equal(canTransition(TRIP_STATUS.COMPLETED, TRIP_STATUS.ACTIVE, TRIP_TRANSITIONS), false);
    assert.equal(canTransition(TRIP_STATUS.PAUSED, TRIP_STATUS.COMPLETED, TRIP_TRANSITIONS), false);
    assert.equal(canTransition(TRIP_STATUS.NOT_STARTED, TRIP_STATUS.PAUSED, TRIP_TRANSITIONS), false);
  });

  it('identifies sequence-based Center Point progression correctly', () => {
    // Center point appears at sequence 1, 4, 7
    // From sequence 1 -> next is CS Dept (seq 2)
    assert.equal(nextRouteStop(route, 1, []).sequence, 2);
    // From sequence 3 (Criminology) -> next is Center Point (seq 4)
    assert.equal(nextRouteStop(route, 3, []).sequence, 4);
    // From sequence 6 (Girls Hostel) -> next is Center Point (seq 7)
    assert.equal(nextRouteStop(route, 6, []).sequence, 7);
  });

  it('correctly handles final stop sequence 7 without auto-ending', () => {
    const lastStop = route[route.length - 1];
    assert.equal(lastStop.sequence, 7);
    assert.equal(lastStop.stop.name, 'Center Point');
    // Once currentSequence reaches 7, next is null (final destination reached)
    assert.equal(nextRouteStop(route, 7, []), null);
  });
});

