const mongoose = require('mongoose');

const driverSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    phone: { type: String, required: true, trim: true },
    assignedBus: { type: mongoose.Schema.Types.ObjectId, ref: 'Bus' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Driver', driverSchema);
