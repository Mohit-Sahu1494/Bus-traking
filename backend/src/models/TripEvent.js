const mongoose = require('mongoose');
const { TRIP_EVENT_TYPES } = require('../utils/constants');

const tripEventSchema = new mongoose.Schema(
  {
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', required: true, index: true },
    type: { type: String, enum: Object.values(TRIP_EVENT_TYPES), required: true },
    stop: { type: mongoose.Schema.Types.ObjectId, ref: 'Stop' },
    routeStop: { type: mongoose.Schema.Types.ObjectId, ref: 'RouteStop' },
    timestamp: { type: Date, default: Date.now },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

module.exports = mongoose.model('TripEvent', tripEventSchema);
