const mongoose = require('mongoose');

const routeSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    isActive: { type: Boolean, default: true },
    campus: { type: String, default: 'Dr. Harisingh Gour University' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Route', routeSchema);
