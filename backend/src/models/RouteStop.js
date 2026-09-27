const mongoose = require('mongoose');

const routeStopSchema = new mongoose.Schema(
  {
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true, index: true },
    stop: { type: mongoose.Schema.Types.ObjectId, ref: 'Stop', required: true },
    sequence: { type: Number, required: true },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
  },
  { timestamps: true }
);

routeStopSchema.index({ route: 1, sequence: 1 }, { unique: true });

module.exports = mongoose.model('RouteStop', routeStopSchema);
