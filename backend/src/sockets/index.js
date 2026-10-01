const { Server } = require('socket.io');
const { env } = require('../config/env');
const { verifyToken } = require('../utils/jwt');
const { setIo } = require('./emitter');
const { handleDriverLocation, handleDriverDisconnect } = require('../services/locationService');
const { parse, locationSchema } = require('../validators');
const { ROLES, SOCKET_EVENTS } = require('../utils/constants');

const DRIVER_ONLY = new Set([
  'driver:location',
  'driver:heartbeat',
]);

function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: env.corsOrigin === '*' ? true : env.corsOrigin.split(','), credentials: true },
    pingInterval: 10000,
    pingTimeout: 20000,
  });

  setIo(io);

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) return next(new Error('Authentication required'));
      socket.user = verifyToken(token);
      return next();
    } catch (err) {
      return next(new Error(err.message || 'Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const { sub, role } = socket.user;
    socket.join('campus');
    socket.join(`user:${sub}`);
    socket.join(`role:${role}`);

    socket.emit('connected', { userId: sub, role });

    const handleLocationEvent = async (payload, ack) => {
      try {
        if (role !== ROLES.DRIVER && role !== ROLES.ADMIN) {
          throw new Error('Students cannot publish driver GPS.');
        }
        const coords = parse(locationSchema, payload);
        const result = await handleDriverLocation(sub, coords);
        if (typeof ack === 'function') ack({ ok: true, result });
      } catch (err) {
        if (typeof ack === 'function') ack({ ok: false, error: err.message });
      }
    };

    socket.on('driver:location', handleLocationEvent);
    socket.on('driver_location', handleLocationEvent);
    socket.on('driver_location_updated', handleLocationEvent);

    socket.on('driver:heartbeat', async (_payload, ack) => {
      try {
        if (role !== ROLES.DRIVER && role !== ROLES.ADMIN) {
          throw new Error('Not allowed');
        }
        await handleDriverLocation(sub, {
          latitude: _payload?.latitude,
          longitude: _payload?.longitude,
          speed: _payload?.speed || 0,
        }).catch(() => null);
        if (typeof ack === 'function') ack({ ok: true });
      } catch (err) {
        if (typeof ack === 'function') ack({ ok: false, error: err.message });
      }
    });

    socket.onAny((event) => {
      if (event.startsWith('driver_') || DRIVER_ONLY.has(event)) {
        if (role !== ROLES.DRIVER && role !== ROLES.ADMIN) {
          socket.emit('error', { message: 'Driver-only event rejected.' });
        }
      }
    });

    socket.on('disconnect', async () => {
      if (role === ROLES.DRIVER) {
        // Check if driver has any other connected sockets
        const socketsInRoom = io.sockets.adapter.rooms.get(`user:${sub}`);
        if (!socketsInRoom || socketsInRoom.size === 0) {
          await handleDriverDisconnect(sub);
        }
      }
    });
  });

  return io;
}

module.exports = { initSocket, SOCKET_EVENTS };
