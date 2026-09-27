const http = require('http');
const { env } = require('./config/env');
const { connectDb } = require('./config/db');
const { connectRedis } = require('./config/redis');
const { initFirebase } = require('./config/firebase');
const { createApp } = require('./app');
const { initSocket } = require('./sockets');
const { startHeartbeatMonitor } = require('./services/locationService');

async function main() {
  await connectDb();
  await connectRedis();
  initFirebase();

  const app = createApp();
  const server = http.createServer(app);
  initSocket(server);
  startHeartbeatMonitor();

  server.listen(env.port, () => {
    console.log(`Campus bus API listening on port ${env.port}`);
  });
}

main().catch((err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});
