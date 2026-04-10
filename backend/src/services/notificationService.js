const { Notification, NotificationPreference, User, Task } = require('../models');
const { Op } = require('sequelize');
const logger = require('../utils/logger');
const RBACService = require('./rbacService');
const socketConfig = require('../config/socket');

/**
 * Notification Service - Handles all notification operations
 */
class NotificationService {
  /**
   * Create a notification
   * @param {number} userId - User ID to receive notification
   * @param {string} type - Notification type (task_assigned, task_completed, etc.)
   * @param {object} data - Notification data {title, description, taskId, metadata}
   * @returns {Promise<object>} Created notification
   */
  static async createNotification(userId, type, data) {
    try {
      // Check if user exists
      const user = await User.findByPk(userId);
      if (!user) {
        logger.warn(`Attempting to create notification for non-existent user: ${userId}`);
        return null;
      }

      // Check notification preferences
      const prefs = await NotificationPreference.findOne({
        where: { user_id: userId }
      });

      // If user has preferences and this notification type is disabled, skip creation
      if (prefs && !prefs[type]) {
        logger.debug(`Notification ${type} disabled for user ${userId}`);
        return null;
      }

      // Create notification
      const notification = await Notification.create({
        user_id: userId,
        task_id: data.taskId || null,
        type,
        title: data.title,
        description: data.description || null,
        metadata: data.metadata || null,
        read: false
      });

      // Fetch with associations
      const fullNotification = await Notification.findByPk(notification.id, {
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
          { model: Task, as: 'task', attributes: ['id', 'title', 'status'] }
        ]
      });

      // Emit notification in real-time via Socket.io if available
      if (global.io) {
        try {
          socketConfig.emitToUser(global.io, userId, {
            id: fullNotification.id,
            type: fullNotification.type,
            title: fullNotification.title,
            description: fullNotification.description,
            taskId: fullNotification.task_id,
            read: fullNotification.read,
            createdAt: fullNotification.createdAt,
            task: fullNotification.task,
            metadata: fullNotification.metadata
          });
          logger.debug(`Notification emitted to user ${userId} via Socket.io`);
        } catch (socketError) {
          logger.warn(`Failed to emit notification via Socket.io: ${socketError.message}`);
        }
      }

      return fullNotification;
    } catch (error) {
      logger.error('Error creating notification', { error: error.message, userId, type });
      throw error;
    }
  }

  /**
   * Mark notification as read
   * @param {number} notificationId - Notification ID
   * @param {object} user - Current user (for authorization)
   * @returns {Promise<object>} Updated notification
   */
  static async markAsRead(notificationId, user) {
    try {
      const notification = await Notification.findByPk(notificationId);

      if (!notification) {
        throw new Error('Notification not found');
      }

      // Check authorization - user can only mark their own notifications as read
      if (notification.user_id !== user.id) {
        throw new Error('Unauthorized to mark this notification as read');
      }

      // Update notification
      await notification.update({
        read: true,
        read_at: new Date()
      });

      return notification;
    } catch (error) {
      logger.error('Error marking notification as read', { error: error.message, notificationId });
      throw error;
    }
  }

  /**
   * Mark all notifications as read for a user
   * @param {number} userId - User ID
   * @returns {Promise<number>} Number of notifications updated
   */
  static async markAllAsRead(userId) {
    try {
      const [updatedCount] = await Notification.update(
        { read: true, read_at: new Date() },
        {
          where: {
            user_id: userId,
            read: false
          }
        }
      );

      return updatedCount;
    } catch (error) {
      logger.error('Error marking all notifications as read', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get unread notification count for user
   * @param {number} userId - User ID
   * @returns {Promise<number>} Unread count
   */
  static async getUnreadCount(userId) {
    try {
      const count = await Notification.count({
        where: {
          user_id: userId,
          read: false
        }
      });

      return count;
    } catch (error) {
      logger.error('Error getting unread count', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get user's notifications with pagination
   * @param {number} userId - User ID
   * @param {number} page - Page number (default 1)
   * @param {number} limit - Items per page (default 20)
   * @param {object} filters - Optional filters {read, type, taskId}
   * @returns {Promise<object>} Paginated notifications
   */
  static async getUserNotifications(userId, page = 1, limit = 20, filters = {}) {
    try {
      const offset = (page - 1) * limit;

      // Build where clause
      const whereClause = { user_id: userId };

      if (filters.read !== undefined) {
        whereClause.read = filters.read;
      }

      if (filters.type) {
        whereClause.type = filters.type;
      }

      if (filters.taskId) {
        whereClause.task_id = filters.taskId;
      }

      const { rows, count } = await Notification.findAndCountAll({
        where: whereClause,
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
          { model: Task, as: 'task', attributes: ['id', 'title', 'status'] }
        ],
        order: [['created_at', 'DESC']],
        limit,
        offset
      });

      return {
        notifications: rows,
        total: count,
        page,
        limit,
        totalPages: Math.ceil(count / limit)
      };
    } catch (error) {
      logger.error('Error getting user notifications', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Delete a notification
   * @param {number} notificationId - Notification ID
   * @param {object} user - Current user (for authorization)
   * @returns {Promise<boolean>} Success status
   */
  static async deleteNotification(notificationId, user) {
    try {
      const notification = await Notification.findByPk(notificationId);

      if (!notification) {
        throw new Error('Notification not found');
      }

      // Check authorization - user can only delete their own notifications
      if (notification.user_id !== user.id) {
        throw new Error('Unauthorized to delete this notification');
      }

      await notification.destroy();
      return true;
    } catch (error) {
      logger.error('Error deleting notification', { error: error.message, notificationId });
      throw error;
    }
  }

  /**
   * Delete all read notifications for a user
   * @param {number} userId - User ID
   * @returns {Promise<number>} Number of notifications deleted
   */
  static async deleteReadNotifications(userId) {
    try {
      const deletedCount = await Notification.destroy({
        where: {
          user_id: userId,
          read: true
        }
      });

      return deletedCount;
    } catch (error) {
      logger.error('Error deleting read notifications', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get user's notification preferences
   * @param {number} userId - User ID
   * @returns {Promise<object>} Notification preferences
   */
  static async getNotificationPreferences(userId) {
    try {
      let prefs = await NotificationPreference.findOne({
        where: { user_id: userId }
      });

      // Create default preferences if not exists
      if (!prefs) {
        prefs = await NotificationPreference.create({ user_id: userId });
      }

      return prefs;
    } catch (error) {
      logger.error('Error getting notification preferences', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Update user's notification preferences
   * @param {number} userId - User ID
   * @param {object} updates - Updated preferences
   * @returns {Promise<object>} Updated preferences
   */
  static async updateNotificationPreferences(userId, updates) {
    try {
      let prefs = await NotificationPreference.findOne({
        where: { user_id: userId }
      });

      if (!prefs) {
        prefs = await NotificationPreference.create({ user_id: userId });
      }

      await prefs.update(updates);
      return prefs;
    } catch (error) {
      logger.error('Error updating notification preferences', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Send notification to task creator when task is completed
   * @param {object} task - Task object
   */
  static async notifyTaskCompleted(task) {
    try {
      if (!task.created_by_user_id) return;

      const completedByUser = await User.findByPk(task.assigned_to_user_id, {
        attributes: ['name']
      });

      await this.createNotification(
        task.created_by_user_id,
        'task_completed',
        {
          title: `Task "${task.title}" has been completed`,
          description: `${completedByUser?.name || 'A user'} has marked the task as complete and is pending your review.`,
          taskId: task.id,
          metadata: {
            completed_by_user_id: task.assigned_to_user_id,
            task_title: task.title
          }
        }
      );
    } catch (error) {
      logger.error('Error notifying task completed', { error: error.message, taskId: task.id });
    }
  }

  /**
   * Send notification when task is assigned
   * @param {object} task - Task object
   */
  static async notifyTaskAssigned(task) {
    try {
      if (!task.assigned_to_user_id) return;

      const createdByUser = await User.findByPk(task.created_by_user_id, {
        attributes: ['name']
      });

      await this.createNotification(
        task.assigned_to_user_id,
        'task_assigned',
        {
          title: `New task assigned: "${task.title}"`,
          description: `${createdByUser?.name || 'Your manager'} has assigned you a new task.`,
          taskId: task.id,
          metadata: {
            assigned_by_user_id: task.created_by_user_id,
            task_title: task.title,
            task_status: task.status
          }
        }
      );
    } catch (error) {
      logger.error('Error notifying task assigned', { error: error.message, taskId: task.id });
    }
  }

  /**
   * Send notification when task status changes
   * @param {object} task - Task object
   * @param {string} previousStatus - Previous status
   */
  static async notifyTaskStatusChanged(task, previousStatus) {
    try {
      if (!task.assigned_to_user_id) return;

      await this.createNotification(
        task.assigned_to_user_id,
        'task_status_changed',
        {
          title: `Task "${task.title}" status changed`,
          description: `The task status has changed from "${previousStatus}" to "${task.status}".`,
          taskId: task.id,
          metadata: {
            previous_status: previousStatus,
            current_status: task.status,
            task_title: task.title
          }
        }
      );
    } catch (error) {
      logger.error('Error notifying task status changed', { error: error.message, taskId: task.id });
    }
  }

  /**
   * Clear old notifications (older than 30 days)
   * @returns {Promise<number>} Number of deleted notifications
   */
  static async clearOldNotifications() {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const deletedCount = await Notification.destroy({
        where: {
          created_at: {
            [Op.lt]: thirtyDaysAgo
          },
          read: true
        }
      });

      logger.info(`Cleared ${deletedCount} old notifications`);
      return deletedCount;
    } catch (error) {
      logger.error('Error clearing old notifications', { error: error.message });
      throw error;
    }
  }

  /**
   * Notify when task is submitted for approval
   * @param {number} taskId - Task ID
   * @param {number} approverId - ID of the approver
   * @param {string} taskTitle - Title of the task
   * @param {number} submittedBy - ID of user who submitted
   */
  static async notifyTaskSubmittedForApproval(taskId, approverId, taskTitle, submittedBy) {
    try {
      const submitter = await User.findByPk(submittedBy);
      
      // BUG-001 FIX: Use correct 3-parameter signature (userId, type, data)
      await this.createNotification(approverId, 'task_approval_pending', {
        title: 'Task Pending Approval',
        description: `"${taskTitle}" is pending your approval${submitter ? ` from ${submitter.name}` : ''}`,
        taskId: taskId,
        metadata: {
          task_id: taskId,
          submitted_by: submittedBy,
          action: 'approval_requested'
        }
      });

      // Emit Socket.io event to notify approver in real-time
      if (global.io) {
        global.io.to(`user:${approverId}`).emit('task_approval_pending', {
          taskId,
          taskTitle,
          submittedBy,
          submitterName: submitter ? submitter.name : 'Unknown'
        });
      }
    } catch (error) {
      logger.error('Error notifying task submitted for approval', { error: error.message });
      // Don't throw - notifications should not block main operation
    }
  }

  /**
   * Notify when task is approved
   * @param {number} taskId - Task ID
   * @param {string} taskTitle - Title of the task
   * @param {number} approverId - ID of the approver
   */
  static async notifyTaskApproved(taskId, taskTitle, approverId) {
    try {
      const task = await Task.findByPk(taskId, {
        include: [
          { model: User, as: 'assignee', attributes: ['id'] },
          { model: User, as: 'creator', attributes: ['id'] }
        ]
      });

      if (!task) return;

      const approver = await User.findByPk(approverId);
      const recipientIds = new Set([task.assigned_to_user_id, task.created_by_user_id]);

      for (const recipientId of recipientIds) {
        if (recipientId && recipientId !== approverId) {
          // BUG-013 FIX: Use correct 3-parameter signature (userId, type, data)
          await this.createNotification(recipientId, 'task_approval_approved', {
            title: 'Task Approved',
            description: `"${taskTitle}" has been approved${approver ? ` by ${approver.name}` : ''}`,
            taskId: taskId,
            metadata: {
              task_id: taskId,
              approved_by: approverId,
              action: 'approval_approved'
            }
          });
        }
      }

      // Emit Socket.io event to team
      if (global.io && task.department_id) {
        global.io.to(`dept:${task.department_id}`).emit('task_approval_approved', {
          taskId,
          taskTitle,
          approvedBy: approver ? approver.name : 'Unknown'
        });
      }
    } catch (error) {
      logger.error('Error notifying task approved', { error: error.message });
    }
  }

  /**
   * Notify when task is rejected
   * @param {number} taskId - Task ID
   * @param {string} taskTitle - Title of the task
   * @param {number} approverId - ID of the approver
   * @param {string} reason - Rejection reason
   */
  static async notifyTaskRejected(taskId, taskTitle, approverId, reason) {
    try {
      const task = await Task.findByPk(taskId, {
        include: [
          { model: User, as: 'assignee', attributes: ['id'] },
          { model: User, as: 'creator', attributes: ['id'] }
        ]
      });

      if (!task) return;

      const approver = await User.findByPk(approverId);
      const recipientIds = new Set([task.assigned_to_user_id, task.created_by_user_id]);

      for (const recipientId of recipientIds) {
        if (recipientId && recipientId !== approverId) {
          // BUG-013 FIX: Use correct 3-parameter signature (userId, type, data)
          await this.createNotification(recipientId, 'task_approval_rejected', {
            title: 'Task Rejected',
            description: `"${taskTitle}" has been rejected${approver ? ` by ${approver.name}` : ''}. Reason: ${reason}`,
            taskId: taskId,
            metadata: {
              task_id: taskId,
              rejected_by: approverId,
              reason: reason,
              action: 'approval_rejected'
            }
          });
        }
      }

      // Emit Socket.io event to team
      if (global.io && task.department_id) {
        global.io.to(`dept:${task.department_id}`).emit('task_approval_rejected', {
          taskId,
          taskTitle,
          rejectedBy: approver ? approver.name : 'Unknown',
          reason
        });
      }
    } catch (error) {
      logger.error('Error notifying task rejected', { error: error.message });
    }
  }

  /**
   * Get notifications for multiple users (useful for broadcasting)
   * @param {array} userIds - Array of user IDs
   * @param {string} type - Notification type filter (optional)
   * @returns {Promise<object>} Map of userId to notifications
   */
  static async getNotificationsForUsers(userIds, type = null) {
    try {
      const where = {
        user_id: {
          [Op.in]: userIds
        }
      };

      if (type) {
        where.type = type;
      }

      const notifications = await Notification.findAll({
        where,
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
          { model: Task, as: 'task', attributes: ['id', 'title', 'status'] }
        ]
      });

      // Group by user ID
      const result = {};
      userIds.forEach(userId => {
        result[userId] = notifications.filter(n => n.user_id === userId);
      });

      return result;
    } catch (error) {
      logger.error('Error getting notifications for users', { error: error.message });
      throw error;
    }
  }
}

module.exports = NotificationService;
