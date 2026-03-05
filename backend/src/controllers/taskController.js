const TaskService = require('../services/taskService');
const logger = require('../utils/logger');

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
      const task = await TaskService.createTask(req.body, req.user);
      
      logger.info(`Task created: ${task.id} by user ${req.user.id}`);
      
      res.status(201).json({
        success: true,
        data: task
      });
    } catch (error) {
      logger.error('Create task error:', error);
      next(error);
    }
  }

  static async updateTask(req, res, next) {
    try {
      const task = await TaskService.updateTask(req.params.id, req.body, req.user);
      
      logger.info(`Task updated: ${task.id} by user ${req.user.id}`);
      
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