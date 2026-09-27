const { verifyToken } = require('../utils/jwt');
const { AppError } = require('../utils/errors');
const { User } = require('../models');

async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      throw new AppError('Please log in to continue.', 401, 'UNAUTHENTICATED');
    }
    const payload = verifyToken(token);
    const user = await User.findById(payload.sub);
    if (!user) {
      throw new AppError('Account not found.', 401, 'UNAUTHENTICATED');
    }
    req.user = user;
    req.auth = payload;
    next();
  } catch (err) {
    next(err);
  }
}

function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new AppError('You do not have permission to do that.', 403, 'FORBIDDEN'));
    }
    next();
  };
}

module.exports = { authenticate, requireRoles };
