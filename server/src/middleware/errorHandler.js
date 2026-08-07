'use strict';

const ApiError = require('../utils/ApiError');

function notFound(req, _res, next) {
  next(new ApiError(404, `No route for ${req.method} ${req.originalUrl}`));
}

/**
 * Maps errors to JSON responses.
 *
 * ORA-20001 / ORA-20002 come from trg_payment_biz_rules and are business
 * rules (BR-19, BR-20), not server faults — they get surfaced to the user
 * as 422 with the trigger's own message, which is written to be readable.
 */
// eslint-disable-next-line no-unused-vars -- Express needs the 4-arg shape
function errorHandler(err, _req, res, _next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({
      error: err.message,
      ...(err.details ? { details: err.details } : {}),
    });
  }

  const message = err.message || 'Unexpected server error.';
  if (message.includes('ORA-00942')) {
    return res.status(503).json({
      error: 'Database schema is not installed. Run database/01_create_tables.sql through 04_views.sql as the KRISHICHAIN schema.',
    });
  }
  const businessRule = message.match(/ORA-2000[12]:\s*(.+?)(?:\n|ORA-|$)/);
  if (businessRule) {
    return res.status(422).json({ error: businessRule[1].trim() });
  }

  console.error('[unhandled]', err);
  return res.status(500).json({ error: 'Unexpected server error.' });
}

module.exports = { notFound, errorHandler };
