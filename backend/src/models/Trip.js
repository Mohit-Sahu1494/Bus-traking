const mongoose = require('mongoose');
const { TRIP_STATUS } = require('../utils/constants');

const tripSchema = new mongoose.Schema(
  {
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver', required: true, index: true },
    bus: { type: mongoose.Schema.Types.ObjectId, ref: 'Bus', required: true, index: true },
    route: { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
    status: { type: String, enum: Object.values(TRIP_STATUS), default: TRIP_STATUS.ACTIVE, index: true },
    currentSequence: { type: Number, default: 0 },
    startedAt: { type: Date, default: Date.now },
    endedAt: Date,
    durationMs: Number,
    pauseReason: String,
    completedSequences: { type: [Number], default: [] },
    skippedSequences: { type: [Number], default: [] },
  },
  { timestamps: true }
);

tripSchema.index({ driver: 1, startedAt: -1 });
tripSchema.index({ bus: 1, status: 1 });

module.exports = mongoose.model('Trip', tripSchema);
