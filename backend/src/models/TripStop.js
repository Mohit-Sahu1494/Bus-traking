const mongoose = require('mongoose');

const tripStopSchema = new mongoose.Schema(
  {
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', required: true, index: true },
    routeStop: { type: mongoose.Schema.Types.ObjectId, ref: 'RouteStop', required: true },
    sequence: { type: Number, required: true },
    status: {
      type: String,
      enum: ['PENDING', 'CURRENT', 'COMPLETED', 'SKIPPED'],
      default: 'PENDING',
    },
    arrivedAt: Date,
    skippedAt: Date,
  },
  { timestamps: true }
);

tripStopSchema.index({ trip: 1, sequence: 1 }, { unique: true });

module.exports = mongoose.model('TripStop', tripStopSchema);
