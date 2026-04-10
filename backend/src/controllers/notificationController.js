const NotificationService = require('../services/notificationService');
const logger = require('../utils/logger');

/**
 * Notification Controller - Handles notification API endpoints
 */

/**
 * Get user's notifications with pagination
 * GET /api/v1/notifications
 */
exports.getUserNotifications = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, read, type } = req.query;
    const filters = {};

    if (read !== undefined) {
      filters.read = read === 'true';
    }

    if (type) {
      filters.type = type;
    }

    const result = await NotificationService.getUserNotifications(
      req.user.id,
      parseInt(page),
      parseInt(limit),
      filters
    );

    return res.status(200).json({
      success: true,
      data: result.notifications,
      pagination: {
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: result.totalPages
      }
    });
  } catch (error) {
    logger.error('Error in getUserNotifications', { error: error.message });
    next(error);
  }
};

/**
 * Mark notification as read
 * PUT /api/v1/notifications/:id/read
 */
exports.markAsRead = async (req, res, next) => {
  try {
    const { id } = req.params;

    const notification = await NotificationService.markAsRead(parseInt(id), req.user);

    return res.status(200).json({
      success: true,
      message: 'Notification marked as read',
      data: notification
    });
  } catch (error) {
    logger.error('Error in markAsRead', { error: error.message });

    if (error.message === 'Notification not found') {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    if (error.message.includes('Unauthorized')) {
      return res.status(403).json({
        success: false,
        message: error.message
      });
    }

    next(error);
  }
};

/**
 * Mark all notifications as read
 * PUT /api/v1/notifications/mark-all-read
 */
exports.markAllAsRead = async (req, res, next) => {
  try {
    const updatedCount = await NotificationService.markAllAsRead(req.user.id);

    return res.status(200).json({
      success: true,
      message: `${updatedCount} notifications marked as read`,
      data: { updated: updatedCount }
    });
  } catch (error) {
    logger.error('Error in markAllAsRead', { error: error.message });
    next(error);
  }
};

/**
 * Get unread notification count
 * GET /api/v1/notifications/count
 */
exports.getUnreadCount = async (req, res, next) => {
  try {
    const count = await NotificationService.getUnreadCount(req.user.id);

    return res.status(200).json({
      success: true,
      data: { unreadCount: count }
    });
  } catch (error) {
    logger.error('Error in getUnreadCount', { error: error.message });
    next(error);
  }
};

/**
 * Delete a notification
 * DELETE /api/v1/notifications/:id
 */
exports.deleteNotification = async (req, res, next) => {
  try {
    const { id } = req.params;

    await NotificationService.deleteNotification(parseInt(id), req.user);

    return res.status(200).json({
      success: true,
      message: 'Notification deleted successfully'
    });
  } catch (error) {
    logger.error('Error in deleteNotification', { error: error.message });

    if (error.message === 'Notification not found') {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    if (error.message.includes('Unauthorized')) {
      return res.status(403).json({
        success: false,
        message: error.message
      });
    }

    next(error);
  }
};

/**
 * Delete all read notifications
 * DELETE /api/v1/notifications/delete-read
 */
exports.deleteReadNotifications = async (req, res, next) => {
  try {
    const deletedCount = await NotificationService.deleteReadNotifications(req.user.id);

    return res.status(200).json({
      success: true,
      message: `${deletedCount} read notifications deleted`,
      data: { deleted: deletedCount }
    });
  } catch (error) {
    logger.error('Error in deleteReadNotifications', { error: error.message });
    next(error);
  }
};

/**
 * Get notification preferences
 * GET /api/v1/notifications/preferences
 */
exports.getPreferences = async (req, res, next) => {
  try {
    const preferences = await NotificationService.getNotificationPreferences(req.user.id);

    return res.status(200).json({
      success: true,
      data: preferences
    });
  } catch (error) {
    logger.error('Error in getPreferences', { error: error.message });
    next(error);
  }
};

/**
 * Update notification preferences
 * PUT /api/v1/notifications/preferences
 */
exports.updatePreferences = async (req, res, next) => {
  try {
    const updates = req.body;

    // Validate allowed fields
    const allowedFields = [
      'task_assigned',
      'task_completed',
      'task_commented',
      'task_deadline_approaching',
      'task_status_changed',
      'task_review_pending',
      'task_review_approved',
      'task_review_rejected',
      'email_notifications',
      'push_notifications'
    ];

    const filteredUpdates = {};
    Object.keys(updates).forEach(key => {
      if (allowedFields.includes(key)) {
        filteredUpdates[key] = updates[key];
      }
    });

    const preferences = await NotificationService.updateNotificationPreferences(
      req.user.id,
      filteredUpdates
    );

    return res.status(200).json({
      success: true,
      message: 'Notification preferences updated',
      data: preferences
    });
  } catch (error) {
    logger.error('Error in updatePreferences', { error: error.message });
    next(error);
  }
};
