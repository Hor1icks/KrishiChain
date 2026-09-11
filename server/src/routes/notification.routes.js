'use strict';

const express = require('express');
const notifications = require('../services/notification.service');
const { authenticate } = require('../middleware/authenticate');
const param = require('../utils/params');

const router = express.Router();
router.use(authenticate);

router.get('/', async (req, res, next) => {
  try {
    res.json(await notifications.listForUser(req.user.userId));
  } catch (err) {
    next(err);
  }
});

router.post('/:notificationId/read', async (req, res, next) => {
  try {
    res.json(
      await notifications.markRead(
        req.user.userId,
        param.id(req.params.notificationId, 'notificationId')
      )
    );
  } catch (err) {
    next(err);
  }
});

module.exports = router;
