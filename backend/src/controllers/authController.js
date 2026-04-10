const AuthService = require('../services/authService');
const logger = require('../utils/logger');

class AuthController {
  static async login(req, res, next) {
    try {
      const { email, password } = req.body;
      // 'email' field accepts email address OR username
      const result = await AuthService.login(email, password);

      logger.info(`User logged in: ${email}`);
      
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('Login error:', error);
      res.status(401).json({
        success: false,
        message: error.message
      });
    }
  }

  static async forgotPassword(req, res, next) {
    try {
      const { email } = req.body;
      const result = await AuthService.forgotPassword(email);
      
      res.json({
        success: true,
        message: result.message
      });
    } catch (error) {
      logger.error('Forgot password error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to process password reset request'
      });
    }
  }

  static async resetPassword(req, res, next) {
    try {
      const { token, password } = req.body;
      const result = await AuthService.resetPassword(token, password);
      
      res.json({
        success: true,
        message: result.message
      });
    } catch (error) {
      logger.error('Reset password error:', error);
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  static async changePassword(req, res, next) {
    try {
      const { current_password, new_password } = req.body;
      const result = await AuthService.changePassword(
        req.user.id,
        current_password,
        new_password
      );
      
      res.json({
        success: true,
        message: result.message
      });
    } catch (error) {
      logger.error('Change password error:', error);
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }
}

module.exports = AuthController;