const UserService = require('../services/userService');
const logger = require('../utils/logger');
const socketConfig = require('../config/socket');

class UserController {
  static async getWorkload(req, res, next) {
    try {
      const userId = parseInt(req.params.id, 10);
      const workload = await UserService.getUserWorkload(userId, req.user);
      
      res.json({
        success: true,
        data: workload
      });
    } catch (error) {
      logger.error('Get workload error:', error);
      if (error.message === 'User not found') {
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

  static async getPerformance(req, res, next) {
    try {
      const userId = parseInt(req.params.id, 10);
      const performance = await UserService.getUserPerformance(userId, req.user);
      
      res.json({
        success: true,
        data: performance
      });
    } catch (error) {
      logger.error('Get performance error:', error);
      if (error.message === 'User not found') {
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

  static async listUsers(req, res, next) {
    try {
      const result = await UserService.listUsers(req.query, req.user);
      
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('List users error:', error);
      next(error);
    }
  }

  static async getUser(req, res, next) {
    try {
      const userId = parseInt(req.params.id, 10);
      const user = await UserService.getUser(userId, req.user);
      
      res.json({
        success: true,
        data: user
      });
    } catch (error) {
      logger.error('Get user error:', error);
      if (error.message === 'User not found') {
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

  static async createUser(req, res, next) {
    try {
      const user = await UserService.createUser(req.body, req.user);
      
      logger.info(`User created: ${user.email} by ${req.user.email}`);

      // Emit real-time user:created event to company room
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('user:created', {
          userId: user.id,
          action: 'created',
          timestamp: new Date()
        });
      }
      
      res.status(201).json({
        success: true,
        data: user
      });
    } catch (error) {
      logger.error('Create user error:', error);
      if (error.message === 'Email already exists') {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async updateUser(req, res, next) {
    try {
      const userId = parseInt(req.params.id, 10);
      const user = await UserService.updateUser(userId, req.body, req.user);
      
      logger.info(`User updated: ${user.email} by ${req.user.email}`);

      // Emit real-time user:updated event to company room
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('user:updated', {
          userId: user.id,
          action: 'updated',
          timestamp: new Date()
        });
      }
      
      res.json({
        success: true,
        data: user
      });
    } catch (error) {
      logger.error('Update user error:', error);
      if (error.message === 'User not found') {
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
      if (error.message === 'Email already exists') {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }

  static async deleteUser(req, res, next) {
    try {
      const userId = parseInt(req.params.id, 10);
      const result = await UserService.deleteUser(userId, req.user);
      
      logger.info(`User deleted: ${userId} by ${req.user.email}`);

      // Emit real-time user:deleted event to company room
      if (global.io && req.user.company_id) {
        global.io.to(`company:${req.user.company_id}`).emit('user:deleted', {
          userId: userId,
          action: 'deleted',
          timestamp: new Date()
        });
      }
      
      res.json({
        success: true,
        message: result.message
      });
    } catch (error) {
      logger.error('Delete user error:', error);
      if (error.message === 'User not found') {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      if (error.message.includes('Cannot delete user with associated tasks')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }
      next(error);
    }
  }
}

module.exports = UserController;