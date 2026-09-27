const { Bus, Route, RouteStop, Stop } = require('../models');
const { asyncHandler } = require('../utils/errors');
const { serializeRouteStop } = require('../utils/tripLogic');
const { getBusLocation } = require('../services/realtimeStore');

const listBuses = asyncHandler(async (req, res) => {
  const buses = await Bus.find().populate('assignedDriver').populate('activeTrip');
  const data = await Promise.all(
    buses.map(async (b) => ({
      id: String(b._id),
      busNumber: b.busNumber,
      status: b.status,
      lastLocation: (await getBusLocation(String(b._id))) || b.lastLocation || null,
      lastLocationAt: b.lastLocationAt,
      activeTrip: b.activeTrip ? String(b.activeTrip._id || b.activeTrip) : null,
    }))
  );
  res.json({
    success: true,
    message: 'Buses retrieved successfully',
    data,
  });
});

const getBus = asyncHandler(async (req, res) => {
  const bus = await Bus.findById(req.params.id);
  if (!bus) {
    const { AppError } = require('../utils/errors');
    throw new AppError('Bus not found.', 404, 'NOT_FOUND');
  }
  const location = await getBusLocation(String(bus._id));
  res.json({
    success: true,
    message: 'Bus retrieved successfully',
    data: { ...bus.toObject(), liveLocation: location },
  });
});

const listRoutes = asyncHandler(async (req, res) => {
  const routes = await Route.find({ isActive: true });
  res.json({
    success: true,
    message: 'Routes retrieved successfully',
    data: routes,
  });
});

const getRoute = asyncHandler(async (req, res) => {
  const route = await Route.findById(req.params.id);
  if (!route) {
    const { AppError } = require('../utils/errors');
    throw new AppError('Route not found.', 404, 'NOT_FOUND');
  }
  const stops = await RouteStop.find({ route: route._id }).populate('stop').sort({ sequence: 1 });
  res.json({
    success: true,
    message: 'Route retrieved successfully',
    data: {
      id: String(route._id),
      name: route.name,
      campus: route.campus,
      stops: stops.map(serializeRouteStop),
    },
  });
});

const listStops = asyncHandler(async (req, res) => {
  const stops = await Stop.find().sort({ name: 1 });
  res.json({
    success: true,
    message: 'Stops retrieved successfully',
    data: stops.map((s) => ({
      id: String(s._id),
      name: s.name,
      code: s.code,
      latitude: s.latitude,
      longitude: s.longitude,
    })),
  });
});

module.exports = { listBuses, getBus, listRoutes, getRoute, listStops };
