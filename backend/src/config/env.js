const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const isProd = (process.env.NODE_ENV || 'development') === 'production';

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  isProd,
  port: Number(process.env.PORT || 4000),
  mongoUri: required('MONGODB_URI'),
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '365d',
  redisUrl: process.env.REDIS_URL || '',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
  firebasePrivateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  stopApproachRadiusM: Number(process.env.STOP_APPROACH_RADIUS_M || 120),
  stopArrivalRadiusM: Number(process.env.STOP_ARRIVAL_RADIUS_M || 60),
  busStaleTimeoutSec: Number(process.env.BUS_STALE_TIMEOUT_SEC || 25),
  seedDriverEmail: process.env.SEED_DRIVER_EMAIL || 'driver@dhsgu.ac.in',
  seedDriverPassword: process.env.SEED_DRIVER_PASSWORD || 'Driver@12345',
  seedAdminEmail: process.env.SEED_ADMIN_EMAIL || 'admin@dhsgu.ac.in',
  seedAdminPassword: process.env.SEED_ADMIN_PASSWORD || 'Admin@12345',
  seedBusNumber: process.env.SEED_BUS_NUMBER || 'BUS-04',
  brevoApiKey: process.env.BREVO_API_KEY || '',
  brevoSenderEmail: process.env.BREVO_SENDER_EMAIL || 'no-reply@dhsgu.ac.in',
  brevoSenderName: process.env.BREVO_SENDER_NAME || 'Campus Bus DHSGU',
};

module.exports = { env };
