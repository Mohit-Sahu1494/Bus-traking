const mongoose = require('mongoose');
const { BUS_STATUS } = require('../utils/constants');

const busSchema = new mongoose.Schema(
  {
    busNumber: { type: String, required: true, unique: true, trim: true },
    status: { type: String, enum: Object.values(BUS_STATUS), default: BUS_STATUS.INACTIVE, index: true },
    assignedDriver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
    activeTrip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip' },
    lastLocation: {
      latitude: Number,
      longitude: Number,
    },
    lastLocationAt: Date,
    lastHeartbeatAt: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Bus', busSchema);
