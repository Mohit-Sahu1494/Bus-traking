const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { env } = require('./config/env');
const { errorHandler } = require('./utils/errors');
const authRoutes = require('./routes/auth');
const studentRoutes = require('./routes/student');
const driverRoutes = require('./routes/driver');
const apiRoutes = require('./routes/index');
const adminRoutes = require('./routes/admin');

function createApp() {
  const app = express();
  app.use(helmet());
  app.use(
    cors({
      origin: env.corsOrigin === '*' ? true : env.corsOrigin.split(','),
      credentials: true,
    })
  );
  app.use(express.json({ limit: '100kb' }));

  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      message: 'Too many attempts. Please wait and try again.',
      error: { code: 'TOO_MANY_REQUESTS', details: null },
    },
  });

  app.get('/health', (req, res) => res.json({ success: true, message: 'Campus Bus API is healthy', data: { status: 'UP' } }));
  app.use('/api/auth', authLimiter, authRoutes);
  app.use('/api/student', studentRoutes);
  app.use('/api/driver', driverRoutes);
  app.use('/api', apiRoutes);
  app.use('/api/admin', adminRoutes);

  app.use((req, res) => {
    res.status(404).json({
      success: false,
      message: 'The requested resource was not found.',
      error: { code: 'NOT_FOUND', details: null },
    });
  });
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
