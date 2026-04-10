const path = require('path');
const fs = require('fs');
const TaskService = require('../services/taskService');
const { TaskAttachment, User } = require('../models');
const logger = require('../utils/logger');
const socketConfig = require('../config/socket');

class TaskController {
  static async listTasks(req, res, next) {
    try {
      const result = await TaskService.listTasks(req.query, req.user);
      
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('List tasks error:', error);
      next(error);
    }
  }

  static async getTask(req, res, next) {
    try {
      const task = await TaskService.getTaskById(req.params.id, req.user);
      
      res.json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Get task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async createTask(req, res, next) {
    try {
      logger.info('Create task request from user:', req.user?.id, 'body keys:', Object.keys(req.body || {}));
      const task = await TaskService.createTask(req.body, req.user);

      logger.info(`Task created: ${task.id} by user ${req.user.id}`);

      // Emit real-time task:created event
      if (global.io) {
        const payload = { taskId: task.id, action: 'created', timestamp: new Date() };
        // Notify company room
        if (req.user.company_id) {
          global.io.to(`company:${req.user.company_id}`).emit('task:created', payload);
        }
        // Notify assigned user specifically
        if (task.assigned_to_user_id && task.assigned_to_user_id !== req.user.id) {
          socketConfig.emitTaskUpdate(global.io, {
            userId: task.assigned_to_user_id,
            taskId: task.id,
            action: 'created',
            data: { title: task.title }
          });
        }
      }

      res.status(201).json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Create task error:', error.message, error.stack);
      // Return the actual error message so the frontend can display it
      const knownErrors = [
        'Assigned user not found',
        'Cannot assign task to user from different company',
        'Cannot determine company for task'
      ];
      if (knownErrors.some(msg => error.message.includes(msg))) {
        return res.status(400).json({ success: false, message: error.message });
      }
      next(error);
    }
  }

  static async updateTask(req, res, next) {
    try {
      const task = await TaskService.updateTask(req.params.id, req.body, req.user);
      
      logger.info(`Task updated: ${task.id} by user ${req.user.id}`);

      // Emit real-time task:updated event
      if (global.io) {
        const payload = { taskId: task.id, action: 'updated', timestamp: new Date() };
        if (req.user.company_id) {
          global.io.to(`company:${req.user.company_id}`).emit('task:updated', payload);
        }
        // Notify assigned user specifically
        if (task.assigned_to_user_id && task.assigned_to_user_id !== req.user.id) {
          socketConfig.emitTaskUpdate(global.io, {
            userId: task.assigned_to_user_id,
            taskId: task.id,
            action: 'updated',
            data: { title: task.title }
          });
        }
      }
      
      res.json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Update task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message === 'Permission denied') {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async deleteTask(req, res, next) {
    try {
      const result = await TaskService.deleteTask(req.params.id, req.user);
      
      logger.info(`Task deleted: ${req.params.id} by user ${req.user.id}`);

      // Emit real-time task:deleted event
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('task:deleted', {
          taskId: parseInt(req.params.id, 10),
          action: 'deleted',
          timestamp: new Date()
        });
      }
      
      res.json({
        success: true,
        message: result.message
      });
    } catch (error) {
      logger.error('Delete task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message === 'Permission denied') {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async completeTask(req, res, next) {
    try {
      const task = await TaskService.completeTask(req.params.id, req.user);
      
      logger.info(`Task completed: ${req.params.id} by user ${req.user.id}`);

      // Emit real-time task:completed event
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('task:completed', {
          taskId: parseInt(req.params.id, 10),
          action: 'completed',
          timestamp: new Date()
        });
      }
      
      res.json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Complete task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('Only the assigned user')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async reopenTask(req, res, next) {
    try {
      const task = await TaskService.reopenTask(req.params.id, req.body.comment, req.user);

      logger.info(`Task reopened: ${req.params.id} by user ${req.user.id}`);

      // Emit real-time task:reopened event
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('task:reopened', {
          taskId: parseInt(req.params.id, 10),
          action: 'reopened',
          timestamp: new Date()
        });
      }

      res.json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Reopen task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('Only the task creator')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('cannot be reopened')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async reviewTask(req, res, next) {
    try {
      const task = await TaskService.reviewTask(req.params.id, req.body, req.user);
      
      logger.info(`Task reviewed: ${req.params.id} by user ${req.user.id} - ${req.body.status}`);
      
      res.json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Review task error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('Permission denied')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('not pending review')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async getTaskActivities(req, res, next) {
    try {
      const activities = await TaskService.getTaskActivities(req.params.id, req.user);
      
      res.json({
        success: true,
        data: activities
      });
    } catch (error) {
      logger.error('Get task activities error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message === 'Permission denied') {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async submitReview(req, res, next) {
    try {
      const review = await TaskService.submitReview(req.params.id, req.body, req.user);
      
      logger.info(`Task review submitted: ${req.params.id} by user ${req.user.id}`);
      
      res.status(201).json({
        success: true,
        data: review
      });
    } catch (error) {
      logger.error('Submit review error:', error);
      if (error.message === 'Task not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message === 'Permission denied') {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('not in a reviewable state')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async getStatistics(req, res, next) {
    try {
      const stats = await TaskService.getStatistics(req.query, req.user);

      res.json({
        success: true,
        data: stats
      });
    } catch (error) {
      logger.error('Get statistics error:', error);
      next(error);
    }
  }

  static async bulkAssign(req, res, next) {
    try {
      const result = await TaskService.bulkAssignTasks(req.body, req.user);
      logger.info(`Bulk assign: ${result.assigned_count} assignments by user ${req.user.id}`);
      res.json({ success: true, data: result });
    } catch (error) {
      logger.error('Bulk assign error:', error);
      if (error.message.includes('No valid')) {
        return res.status(400).json({ success: false, message: error.message });
      }
      next(error);
    }
  }

  static async bulkCreate(req, res, next) {
    try {
      const result = await TaskService.bulkCreateTasks(req.body.tasks, req.user);
      logger.info(`Bulk create: ${result.created_count} tasks by user ${req.user.id}`);
      res.status(201).json({ success: true, data: result });
    } catch (error) {
      logger.error('Bulk create error:', error);
      next(error);
    }
  }

  static async uploadAttachment(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({ success: false, message: 'No file uploaded' });
      }
      const taskId = parseInt(req.params.id, 10);
      const task = await TaskService.getTaskById(taskId, req.user);
      if (!task) return res.status(404).json({ success: false, message: 'Task not found' });

      const attachment = await TaskAttachment.create({
        task_id: taskId,
        uploaded_by_user_id: req.user.id,
        original_name: req.file.originalname,
        stored_name: req.file.filename,
        mime_type: req.file.mimetype,
        file_size: req.file.size
      });

      const result = attachment.toJSON();
      result.uploader = { id: req.user.id, name: req.user.name };
      res.status(201).json({ success: true, data: result });
    } catch (error) {
      if (req.file) {
        fs.unlink(req.file.path, () => {});
      }
      logger.error('Upload attachment error:', error);
      next(error);
    }
  }

  static async getAttachments(req, res, next) {
    try {
      const taskId = parseInt(req.params.id, 10);
      const attachments = await TaskAttachment.findAll({
        where: { task_id: taskId },
        include: [{ model: User, as: 'uploader', attributes: ['id', 'name'] }],
        order: [['created_at', 'DESC']]
      });
      res.json({ success: true, data: attachments });
    } catch (error) {
      logger.error('Get attachments error:', error);
      next(error);
    }
  }

  static async downloadAttachment(req, res, next) {
    try {
      const attachment = await TaskAttachment.findOne({
        where: { id: req.params.attachmentId, task_id: req.params.id }
      });
      if (!attachment) return res.status(404).json({ success: false, message: 'Attachment not found' });

      const filePath = path.join(__dirname, '../../uploads/tasks', attachment.stored_name);
      if (!fs.existsSync(filePath)) {
        return res.status(404).json({ success: false, message: 'File not found on server' });
      }
      res.setHeader('Content-Disposition', `attachment; filename="${attachment.original_name}"`);
      res.setHeader('Content-Type', attachment.mime_type || 'application/octet-stream');
      res.sendFile(filePath);
    } catch (error) {
      logger.error('Download attachment error:', error);
      next(error);
    }
  }

  static async deleteAttachment(req, res, next) {
    try {
      const attachment = await TaskAttachment.findOne({
        where: { id: req.params.attachmentId, task_id: req.params.id }
      });
      if (!attachment) return res.status(404).json({ success: false, message: 'Attachment not found' });

      const filePath = path.join(__dirname, '../../uploads/tasks', attachment.stored_name);
      if (fs.existsSync(filePath)) fs.unlink(filePath, () => {});

      await attachment.destroy();
      res.json({ success: true, message: 'Attachment deleted' });
    } catch (error) {
      logger.error('Delete attachment error:', error);
      next(error);
    }
  }

  static async getUserWorkloadSummary(req, res, next) {
    try {
      const summary = await TaskService.getUserWorkloadSummary(
        parseInt(req.params.userId, 10),
        req.user
      );
      res.json({ success: true, data: summary });
    } catch (error) {
      logger.error('Workload summary error:', error);
      next(error);
    }
  }
}

module.exports = TaskController;