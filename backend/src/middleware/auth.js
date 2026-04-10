const jwt = require('jsonwebtoken');
const config = require('../config');
const { User } = require('../models');
const logger = require('../utils/logger');
const accountLockout = require('./accountLockout');
const securityConstants = require('../constants/security');

/**
 * Verify JWT token and attach user to request
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const token = authHeader.substring(7);

    try {
      const decoded = jwt.verify(token, config.jwt.secret);
      
      const user = await User.findByPk(decoded.id, {
        attributes: { exclude: ['password_hash'] },
        include: [
          { association: 'company', attributes: ['id', 'name'] },
          { association: 'department', attributes: ['id', 'name'] },
          { association: 'location', attributes: ['id', 'name'] }
        ]
      });

      if (!user) {
        return res.status(401).json({
          success: false,
          message: 'User not found'
        });
      }

      if (!user.is_active) {
        return res.status(401).json({
          success: false,
          message: 'User account is inactive'
        });
      }

      req.user = user;
      next();
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({
          success: false,
          message: 'Token expired'
        });
      }
      
      return res.status(401).json({
        success: false,
        message: 'Invalid token'
      });
    }
  } catch (error) {
    logger.error('Authentication error:', error);
    return res.status(500).json({
      success: false,
      message: 'Authentication failed'
    });
  }
};

/**
 * Require specific roles
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions'
      });
    }

    next();
  };
};

/**
 * Check if user can access company data
 */
const canAccessCompany = (companyId) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    // Superadmin can access all companies
    if (req.user.role === 'superadmin') {
      return next();
    }

    // Others can only access their own company
    if (req.user.company_id !== parseInt(companyId, 10)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied to this company'
      });
    }

    next();
  };
};

module.exports = {
  authenticate,
  requireRole,
  canAccessCompany
};