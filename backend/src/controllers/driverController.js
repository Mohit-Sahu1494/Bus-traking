const { asyncHandler } = require('../utils/errors');
const { parse, pauseTripSchema, skipStopSchema } = require('../validators');
const { Trip } = require('../models');
const {
  startTrip,
  pauseTrip,
  resumeTrip,
  endTrip,
  skipNextStop,
  reachNextStop,
  driverLiveState,
  assignedDriverContext,
} = require('../services/tripService');

const getProfile = asyncHandler(async (req, res) => {
  const driver = await assignedDriverContext(req.user);
  const totals = await Trip.aggregate([
    { $match: { driver: driver._id } },
    {
      $group: {
        _id: null,
        totalTrips: { $sum: 1 },
        completedTrips: { $sum: { $cond: [{ $eq: ['$status', 'COMPLETED'] }, 1, 0] } },
        skippedStops: { $sum: { $size: '$skippedSequences' } },
      },
    },
  ]);
  const stats = totals[0] || { totalTrips: 0, completedTrips: 0, skippedStops: 0 };
  res.json({
    success: true,
    data: {
      name: req.user.name,
      email: req.user.email,
      phone: driver.phone,
      busNumber: driver.assignedBus.busNumber,
      busId: String(driver.assignedBus._id),
      totalTrips: stats.totalTrips,
      completedTrips: stats.completedTrips,
      skippedStops: stats.skippedStops,
    },
  });
});

const listTrips = asyncHandler(async (req, res) => {
  const driver = await assignedDriverContext(req.user);
  const trips = await Trip.find({ driver: driver._id }).sort({ startedAt: -1 }).limit(50).populate('bus', 'busNumber');
  res.json({
    success: true,
    data: trips.map((t) => ({
      tripId: String(t._id),
      driverId: String(t.driver),
      busId: String(t.bus._id || t.bus),
      busNumber: t.bus.busNumber,
      routeId: String(t.route),
      startTime: t.startedAt,
      endTime: t.endedAt || null,
      duration: t.durationMs || null,
      completedStops: t.completedSequences,
      skippedStops: t.skippedSequences,
      status: t.status,
    })),
  });
});

const live = asyncHandler(async (req, res) => {
  const data = await driverLiveState(req.user);
  res.json({ success: true, data });
});

const start = asyncHandler(async (req, res) => {
  const data = await startTrip(req.user, req.body);
  res.status(201).json({ success: true, data });
});

const pause = asyncHandler(async (req, res) => {
  const { reason } = parse(pauseTripSchema, req.body);
  const data = await pauseTrip(req.user, reason);
  res.json({ success: true, data });
});

const resume = asyncHandler(async (req, res) => {
  const data = await resumeTrip(req.user);
  res.json({ success: true, data });
});

const end = asyncHandler(async (req, res) => {
  const data = await endTrip(req.user, Boolean(req.body?.cancelled));
  res.json({ success: true, data });
});

const skip = asyncHandler(async (req, res) => {
  const body = parse(skipStopSchema, req.body || {});
  const data = await skipNextStop(req.user, body.routeStopId);
  res.json({ success: true, data });
});

const reach = asyncHandler(async (req, res) => {
  const body = req.body || {};
  const data = await reachNextStop(req.user, body.routeStopId);
  res.json({ success: true, data });
});

const listBuses = asyncHandler(async (req, res) => {
  const { Driver, Bus } = require('../models');
  const driver = await Driver.findOne({ user: req.user._id }).populate('assignedBus');
  if (!driver) {
    const { AppError } = require('../utils/errors');
    throw new AppError('Driver profile not found.', 404, 'DRIVER_NOT_FOUND');
  }

  const buses = await Bus.find().sort({ busNumber: 1 });
  const activeTrips = await Trip.find({
    status: { $in: ['ACTIVE', 'PAUSED'] },
  }).select('bus driver');

  const activeBusIds = new Set(activeTrips.map((t) => String(t.bus)));
  const currentAssignedBusId = driver.assignedBus ? String(driver.assignedBus._id || driver.assignedBus) : null;

  const data = buses.map((b) => {
    const isCurrent = currentAssignedBusId === String(b._id);
    const hasActiveTrip = activeBusIds.has(String(b._id));
    const isAssignedToOther =
      b.assignedDriver &&
      String(b.assignedDriver) !== String(driver._id);

    const isAvailable = isCurrent || (!hasActiveTrip && !isAssignedToOther);

    return {
      id: String(b._id),
      busNumber: b.busNumber,
      status: b.status,
      isCurrent,
      isAvailable,
      inUse: hasActiveTrip || (isAssignedToOther && !isCurrent),
      reason: hasActiveTrip
        ? 'Currently on an active trip'
        : isAssignedToOther && !isCurrent
          ? 'Currently assigned to another driver'
          : null,
    };
  });

  res.json({
    success: true,
    message: 'Buses retrieved successfully',
    data,
  });
});

const assignBus = asyncHandler(async (req, res) => {
  const { Driver, Bus } = require('../models');
  const { AppError } = require('../utils/errors');
  const driver = await Driver.findOne({ user: req.user._id });
  if (!driver) {
    throw new AppError('Driver profile not found.', 404, 'DRIVER_NOT_FOUND');
  }

  const { busId, busNumber } = req.body || {};

  // Driver cannot switch buses during an active/paused trip
  const activeTrip = await Trip.findOne({
    driver: driver._id,
    status: { $in: ['ACTIVE', 'PAUSED'] },
  });
  if (activeTrip) {
    throw new AppError('Cannot change bus while a trip is active or paused.', 400, 'TRIP_ACTIVE');
  }

  // Find bus by ID or busNumber
  const bus = busId ? await Bus.findById(busId) : await Bus.findOne({ busNumber });
  if (!bus) {
    throw new AppError('Bus not found.', 404, 'BUS_NOT_FOUND');
  }

  // Check if bus is controlled by another active trip
  const busActiveTrip = await Trip.findOne({
    bus: bus._id,
    status: { $in: ['ACTIVE', 'PAUSED'] },
  });
  if (busActiveTrip && String(busActiveTrip.driver) !== String(driver._id)) {
    return res.status(409).json({
      success: false,
      message: 'This bus is currently unavailable',
      error: { code: 'BUS_UNAVAILABLE' },
    });
  }

  // Check if bus is actively assigned to another driver
  if (bus.assignedDriver && String(bus.assignedDriver) !== String(driver._id)) {
    const otherDriverTrip = await Trip.findOne({
      driver: bus.assignedDriver,
      status: { $in: ['ACTIVE', 'PAUSED'] },
    });
    if (otherDriverTrip || bus.status === 'ACTIVE' || bus.status === 'PAUSED') {
      return res.status(409).json({
        success: false,
        message: 'This bus is currently unavailable',
        error: { code: 'BUS_UNAVAILABLE' },
      });
    }
  }

  // Clear previous bus assignedDriver if different
  if (driver.assignedBus && String(driver.assignedBus) !== String(bus._id)) {
    await Bus.updateOne(
      { _id: driver.assignedBus, assignedDriver: driver._id },
      { $unset: { assignedDriver: 1 } }
    );
  }

  // Update driver assignment
  driver.assignedBus = bus._id;
  await driver.save();

  // Update bus assigned driver
  bus.assignedDriver = driver._id;
  await bus.save();

  return res.json({
    success: true,
    message: 'Bus assigned successfully',
    data: {
      busId: String(bus._id),
      busNumber: bus.busNumber,
    },
  });
});

module.exports = {
  getProfile,
  listTrips,
  live,
  start,
  pause,
  resume,
  end,
  skip,
  reach,
  listBuses,
  assignBus,
};

