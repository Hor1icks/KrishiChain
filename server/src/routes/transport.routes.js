'use strict';
const express = require('express');
const service = require('../services/transport.service');
const { authenticate, requireRole } = require('../middleware/authenticate');
const { positiveIntegerParam } = require('../utils/params');
const router = express.Router();
router.use(authenticate, requireRole('TRANSPORT_PERSONNEL'));
router.get('/dashboard', async (req, res, next) => {
  try { res.json(await service.getDashboard(req.user.userId)); } catch (err) { next(err); }
});
router.patch('/assignments/:assignmentId/status', async (req, res, next) => {
  try {
    res.json(await service.updateDelivery(
      req.user.userId, positiveIntegerParam(req, 'assignmentId'), req.body.status
    ));
  } catch (err) { next(err); }
});
module.exports = router;
