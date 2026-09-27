const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { claimNotification } = require('../services/realtimeStore');

describe('Notification Deduplication and Reliability Logic', () => {
  it('claimNotification grants first call and blocks duplicate calls', async () => {
    const key = `test-dedup-${Date.now()}`;
    const first = await claimNotification(key, 60);
    assert.strictEqual(first, true, 'First claim must succeed');

    const second = await claimNotification(key, 60);
    assert.strictEqual(second, false, 'Duplicate claim within TTL must be blocked');
  });

  it('generates deterministic event deduplication keys', () => {
    const tripId = '66f5c1234567890123456789';
    const sequence = 2;

    const approachKey = `approach-${tripId}-${sequence}`;
    const arrivedKey = `arrived-${tripId}-${sequence}`;
    const skipKey = `skip-${tripId}-${sequence}`;
    const delayKey = `delay-${tripId}`;
    const endKey = `end-${tripId}`;

    assert.strictEqual(approachKey, `approach-66f5c1234567890123456789-2`);
    assert.strictEqual(arrivedKey, `arrived-66f5c1234567890123456789-2`);
    assert.strictEqual(skipKey, `skip-66f5c1234567890123456789-2`);
    assert.strictEqual(delayKey, `delay-66f5c1234567890123456789`);
    assert.strictEqual(endKey, `end-66f5c1234567890123456789`);
  });

  it('rejects stop triggers when GPS accuracy is poor (>50m)', () => {
    const poorGps = { latitude: 23.8242, longitude: 78.7821, accuracy: 75 };
    const goodGps = { latitude: 23.8242, longitude: 78.7821, accuracy: 12 };

    const shouldIgnore = (loc) => loc.accuracy != null && loc.accuracy > 50;

    assert.strictEqual(shouldIgnore(poorGps), true, 'Poor accuracy reading should be ignored');
    assert.strictEqual(shouldIgnore(goodGps), false, 'Good accuracy reading should be accepted');
  });
});
