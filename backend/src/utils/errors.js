class AppError extends Error {
  constructor(message, status = 400, code = 'APP_ERROR', details = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  let status = err.status || 500;
  let code = err.code || 'INTERNAL_SERVER_ERROR';
  let message = err.message || 'Something went wrong. Please try again.';
  let details = err.details || null;

  // Handle Mongoose Validation Error
  if (err.name === 'ValidationError') {
    status = 400;
    code = 'VALIDATION_ERROR';
    message = 'Validation failed';
    details = {};
    if (err.errors) {
      for (const key of Object.keys(err.errors)) {
        details[key] = err.errors[key].message;
      }
    }
  }
  // Handle Mongoose Duplicate Key (11000)
  else if (err.code === 11000) {
    status = 409;
    code = 'DUPLICATE_RESOURCE';
    const field = Object.keys(err.keyPattern || err.keyValue || {})[0] || 'field';
    message = `An account or record with this ${field} already exists.`;
    details = { [field]: `${field} is already in use` };
  }
  // Handle CastError (invalid ObjectId)
  else if (err.name === 'CastError') {
    status = 400;
    code = 'INVALID_ID';
    message = 'Invalid resource identifier format.';
    details = null;
  }
  // Handle JWT expired
  else if (err.name === 'TokenExpiredError') {
    status = 401;
    code = 'TOKEN_EXPIRED';
    message = 'Your session has expired. Please login again.';
    details = null;
  }
  // Handle JWT invalid
  else if (err.name === 'JsonWebTokenError') {
    status = 401;
    code = 'INVALID_TOKEN';
    message = 'Invalid authentication token. Please login again.';
    details = null;
  }

  // Hide internal server errors and stack traces in production
  if (status >= 500) {
    console.error(`[SERVER_ERROR] ${req.method} ${req.originalUrl}:`, err.message || err);
    if (process.env.NODE_ENV === 'production') {
      message = 'Something went wrong on the server. Please try again.';
      details = null;
    }
  }

  res.status(status).json({
    success: false,
    message,
    error: {
      code,
      details,
    },
  });
}

module.exports = { AppError, asyncHandler, errorHandler };
