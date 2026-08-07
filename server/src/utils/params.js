'use strict';

const ApiError = require('./ApiError');

/** Parse a route identifier once and reject NaN, decimals, zero and negatives. */
function positiveIntegerParam(req, name) {
  const value = Number(req.params[name]);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw ApiError.badRequest(`${name} must be a positive integer.`);
  }
  return value;
}

module.exports = { positiveIntegerParam };
