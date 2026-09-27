const mongoose = require('mongoose');

const waitingStatusSchema = new mongoose.Schema(
  {
    student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    stop: { type: mongoose.Schema.Types.ObjectId, ref: 'Stop', required: true, index: true },
    trip: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip' },
    isActive: { type: Boolean, default: true, index: true },
    startedAt: { type: Date, default: Date.now },
    endedAt: Date,
  },
  { timestamps: true }
);

waitingStatusSchema.index({ student: 1, isActive: 1 });

module.exports = mongoose.model('WaitingStatus', waitingStatusSchema);
