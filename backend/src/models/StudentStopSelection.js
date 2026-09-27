const mongoose = require('mongoose');

const studentStopSelectionSchema = new mongoose.Schema(
  {
    student: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    stop: { type: mongoose.Schema.Types.ObjectId, ref: 'Stop', required: true },
    selectedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('StudentStopSelection', studentStopSelectionSchema);
