const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const performanceController = require('../controllers/performanceController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/v1/hr/dashboard
 * Main HR dashboard with company KPIs
 * Access: HR, Management, Superadmin
 */
router.get(
  '/dashboard',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  performanceController.getHRDashboard
);

/**
 * GET /api/v1/hr/performance-summary
 * Quick summary of all performance metrics
 * Access: HR, Management, Superadmin
 */
router.get(
  '/performance-summary',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  celebrate({
    [Segments.QUERY]: Joi.object({
      month: Joi.number().integer().min(1).max(12),
      year: Joi.number().integer().min(2020)
    })
  }),
  performanceController.getPerformanceSummary
);

/**
 * GET /api/v1/hr/department-performance
 * Department-wise performance metrics
 * Access: HR, Management, Superadmin
 */
router.get(
  '/department-performance',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  celebrate({
    [Segments.QUERY]: Joi.object({
      department_id: Joi.number().integer().required(),
      month: Joi.number().integer().min(1).max(12),
      year: Joi.number().integer().min(2020)
    })
  }),
  performanceController.getDepartmentPerformance
);

/**
 * GET /api/v1/hr/employee-performance/:id
 * Individual employee performance data
 * Access: Employee (own), HR, Management, Superadmin
 */
router.get(
  '/employee-performance/:id',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  performanceController.getEmployeePerformance
);

/**
 * GET /api/v1/hr/performance-trends
 * Performance trends over time
 * Access: Employee (own), HR, Management, Superadmin
 */
router.get(
  '/performance-trends',
  celebrate({
    [Segments.QUERY]: Joi.object({
      user_id: Joi.number().integer(),
      months: Joi.number().integer().min(1).max(24).default(6)
    })
  }),
  performanceController.getPerformanceTrends
);

/**
 * GET /api/v1/hr/top-performers
 * Top performers in a department
 * Access: HR, Management, Superadmin
 */
router.get(
  '/top-performers',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  celebrate({
    [Segments.QUERY]: Joi.object({
      department_id: Joi.number().integer().required(),
      limit: Joi.number().integer().min(1).max(100).default(10)
    })
  }),
  performanceController.getTopPerformers
);

/**
 * POST /api/v1/hr/performance-report
 * Generate and download comprehensive HR report
 * Access: HR, Management, Superadmin
 */
router.post(
  '/performance-report',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  celebrate({
    [Segments.BODY]: Joi.object({
      month: Joi.number().integer().min(1).max(12).required(),
      year: Joi.number().integer().min(2020).required(),
      format: Joi.string().valid('json', 'csv').default('json')
    })
  }),
  performanceController.generatePerformanceReport
);

module.exports = router;
