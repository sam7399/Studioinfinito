const express = require('express');
const { celebrate, Joi } = require('celebrate');
const { authenticate } = require('../middleware/auth');
const notificationController = require('../controllers/notificationController');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/v1/notifications
 * Get user's notifications with pagination
 * Query params: page, limit, read, type
 */
router.get('/', notificationController.getUserNotifications);

/**
 * GET /api/v1/notifications/count
 * Get unread notification count
 */
router.get('/count', notificationController.getUnreadCount);

/**
 * PUT /api/v1/notifications/mark-all-read
 * Mark all notifications as read
 */
router.put('/mark-all-read', notificationController.markAllAsRead);

/**
 * GET /api/v1/notifications/preferences
 * Get user's notification preferences
 */
router.get('/preferences', notificationController.getPreferences);

/**
 * PUT /api/v1/notifications/preferences
 * Update user's notification preferences
 */
router.put('/preferences', notificationController.updatePreferences);

/**
 * DELETE /api/v1/notifications/delete-read
 * Delete all read notifications
 */
router.delete('/delete-read', notificationController.deleteReadNotifications);

/**
 * PUT /api/v1/notifications/:id/read
 * Mark specific notification as read
 */
router.put(
  '/:id/read',
  celebrate({
    params: Joi.object().keys({
      id: Joi.number().required()
    })
  }),
  notificationController.markAsRead
);

/**
 * DELETE /api/v1/notifications/:id
 * Delete specific notification
 */
router.delete(
  '/:id',
  celebrate({
    params: Joi.object().keys({
      id: Joi.number().required()
    })
  }),
  notificationController.deleteNotification
);

module.exports = router;
