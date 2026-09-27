const { Driver } = require('../models');
const { AppError } = require('../utils/errors');
const { asyncHandler } = require('../utils/errors');
const { ROLES } = require('../utils/constants');

const assignBus = asyncHandler(async (req, res) => {
  const { driverId, busId } = req.body;
  const driver = await Driver.findById(driverId);
  if (!driver) throw new AppError('Driver not found.', 404, 'NOT_FOUND');
  driver.assignedBus = busId;
  await driver.save();
  const { Bus } = require('../models');
  await Bus.findByIdAndUpdate(busId, { assignedDriver: driver._id });
  res.json({ success: true, data: { assigned: true } });
});

module.exports = { assignBus };
