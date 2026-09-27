const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
const bcrypt = require('bcrypt');
const { connectDb } = require('../config/db');
const { env } = require('../config/env');
const { ROLES, BUS_STATUS } = require('../utils/constants');
const { User, Driver, Bus, Stop, Route, RouteStop } = require('../models');
const coords = require('../config/campus-coordinates.json');

async function seed() {
  await connectDb();

  const stopDocs = {};
  for (const stop of coords.stops) {
    stopDocs[stop.code] = await Stop.findOneAndUpdate(
      { code: stop.code },
      {
        name: stop.name,
        code: stop.code,
        latitude: stop.latitude,
        longitude: stop.longitude,
      },
      { upsert: true, new: true }
    );
  }

  const route = await Route.findOneAndUpdate(
    { name: 'Campus Circular Route' },
    {
      name: 'Campus Circular Route',
      campus: 'Dr. Harisingh Gour University',
      isActive: true,
    },
    { upsert: true, new: true }
  );

  await RouteStop.deleteMany({ route: route._id });
  for (let i = 0; i < coords.routeSequences.length; i += 1) {
    const code = coords.routeSequences[i];
    const stop = stopDocs[code];
    await RouteStop.create({
      route: route._id,
      stop: stop._id,
      sequence: i + 1,
      latitude: stop.latitude,
      longitude: stop.longitude,
    });
  }

  const adminHash = await bcrypt.hash(env.seedAdminPassword, 12);
  await User.findOneAndUpdate(
    { email: env.seedAdminEmail.toLowerCase() },
    {
      role: ROLES.ADMIN,
      name: 'Campus Admin',
      email: env.seedAdminEmail.toLowerCase(),
      passwordHash: adminHash,
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const driverUser = await User.findOneAndUpdate(
    { email: env.seedDriverEmail.toLowerCase() },
    {
      role: ROLES.DRIVER,
      name: 'Campus Driver',
      email: env.seedDriverEmail.toLowerCase(),
      passwordHash: await bcrypt.hash(env.seedDriverPassword, 12),
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  const fleet = ['BUS-01', 'BUS-02', 'BUS-03', 'BUS-04'];
  for (const bNum of fleet) {
    await Bus.findOneAndUpdate(
      { busNumber: bNum },
      { busNumber: bNum, status: BUS_STATUS.INACTIVE },
      { upsert: true, new: true }
    );
  }

  const bus = await Bus.findOne({ busNumber: env.seedBusNumber });

  const driver = await Driver.findOneAndUpdate(
    { user: driverUser._id },
    { user: driverUser._id, phone: '9999999999', assignedBus: bus._id },
    { upsert: true, new: true }
  );

  bus.assignedDriver = driver._id;
  await bus.save();

  console.log('Seed complete.');
  console.log(`Driver login: ${env.seedDriverEmail} / ${env.seedDriverPassword}`);
  console.log(`Admin login:  ${env.seedAdminEmail} / ${env.seedAdminPassword}`);
  console.log(`Bus: ${env.seedBusNumber}`);
  console.log('Update stop coordinates in src/config/campus-coordinates.json and re-run seed.');
  process.exit(0);
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
