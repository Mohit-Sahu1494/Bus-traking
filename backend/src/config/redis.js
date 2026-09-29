const Redis = require('ioredis');
const { env } = require('./env');

/** In-memory fallback so local development can run without Redis. Not for production. */
function createMemoryStore() {
  const map = new Map();
  const timers = new Map();

  return {
    async get(key) {
      return map.has(key) ? map.get(key) : null;
    },
    async set(key, value, ...args) {
      map.set(key, String(value));
      const exIndex = args.findIndex((a) => String(a).toUpperCase() === 'EX');
      if (exIndex !== -1 && args[exIndex + 1]) {
        const seconds = Number(args[exIndex + 1]);
        if (timers.has(key)) clearTimeout(timers.get(key));
        const timer = setTimeout(() => {
          map.delete(key);
          timers.delete(key);
        }, seconds * 1000);
        if (typeof timer.unref === 'function') timer.unref();
        timers.set(key, timer);
      }
      return 'OK';
    },
    async del(key) {
      map.delete(key);
      if (timers.has(key)) {
        clearTimeout(timers.get(key));
        timers.delete(key);
      }
      return 1;
    },
    async incr(key) {
      const next = Number(map.get(key) || 0) + 1;
      map.set(key, String(next));
      return next;
    },
    async expire() {
      return 1;
    },
    async ping() {
      return 'PONG';
    },
    on() {},
  };
}

let redis;

async function connectRedis() {
  if (!env.redisUrl) {
    console.warn('REDIS_URL not set — using in-memory store (not for production)');
    redis = createMemoryStore();
    return redis;
  }

  redis = new Redis(env.redisUrl, {
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    lazyConnect: true,
  });

  redis.on('error', (err) => {
    console.error('Redis error:', err.message);
  });

  try {
    await redis.connect();
    await redis.ping();
    console.log('Redis connected');
  } catch (err) {
    console.warn(`Redis unavailable (${err.message}) — falling back to in-memory store`);
    try {
      redis.disconnect();
    } catch (_) {
      /* ignore */
    }
    redis = createMemoryStore();
  }

  return redis;
}

function getRedis() {
  if (!redis) {
    redis = createMemoryStore();
  }
  return redis;
}

module.exports = { connectRedis, getRedis };
