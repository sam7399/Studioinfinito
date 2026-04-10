const PerformanceService = require('../services/performanceService');
const RBACService = require('../services/rbacService');
const logger = require('../utils/logger');

class PerformanceController {
  /**
   * GET /api/v1/hr/dashboard
   * Main HR dashboard with company KPIs
   */
  static async getHRDashboard(req, res, next) {
    try {
      // Check RBAC - only HR and above can access
      const canAccess = await RBACService.canAccessPerformanceData(req.user);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied. Only HR and management can view performance data.'
        });
      }

      const currentDate = new Date();
      const month = req.query.month || currentDate.getMonth() + 1;
      const year = req.query.year || currentDate.getFullYear();

      const report = await PerformanceService.generateHRReport(month, year);

      res.json({
        success: true,
        data: report
      });
    } catch (error) {
      logger.error('Get HR dashboard error:', error);
      next(error);
    }
  }

  /**
   * GET /api/v1/hr/department-performance
   * Department-wise performance metrics
   */
  static async getDepartmentPerformance(req, res, next) {
    try {
      const canAccess = await RBACService.canAccessPerformanceData(req.user);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const departmentId = req.query.department_id;
      const month = req.query.month || new Date().getMonth() + 1;
      const year = req.query.year || new Date().getFullYear();

      if (!departmentId) {
        return res.status(400).json({
          success: false,
          message: 'department_id is required'
        });
      }

      const metrics = await PerformanceService.calculateDepartmentMetrics(departmentId, month, year);
      const performanceRecords = await PerformanceService.calculateDepartmentPerformances(departmentId, month, year);

      res.json({
        success: true,
        data: {
          metrics: metrics,
          employee_performances: performanceRecords
        }
      });
    } catch (error) {
      logger.error('Get department performance error:', error);
      next(error);
    }
  }

  /**
   * GET /api/v1/hr/employee-performance/:id
   * Individual employee performance data
   */
  static async getEmployeePerformance(req, res, next) {
    try {
      const userId = req.params.id;
      const requestingUser = req.user;

      // Check RBAC - user can see own performance or HR/management can see any
      const canAccess = await RBACService.canAccessEmployeePerformance(requestingUser, userId);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied. You can only view your own performance.'
        });
      }

      const report = await PerformanceService.getPerformanceReport(userId);

      res.json({
        success: true,
        data: report
      });
    } catch (error) {
      logger.error('Get employee performance error:', error);
      if (error.message === 'User not found') {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }
      next(error);
    }
  }

  /**
   * GET /api/v1/hr/performance-trends
   * Performance trends over time
   */
  static async getPerformanceTrends(req, res, next) {
    try {
      const userId = req.query.user_id || req.user.id;
      const months = req.query.months ? parseInt(req.query.months, 10) : 6;

      // RBAC check
      const canAccess = await RBACService.canAccessEmployeePerformance(req.user, userId);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const trends = await PerformanceService.getPerformanceTrends(userId, months);

      res.json({
        success: true,
        data: trends
      });
    } catch (error) {
      logger.error('Get performance trends error:', error);
      next(error);
    }
  }

  /**
   * GET /api/v1/hr/top-performers
   * Top performers in a department
   */
  static async getTopPerformers(req, res, next) {
    try {
      const canAccess = await RBACService.canAccessPerformanceData(req.user);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const departmentId = req.query.department_id;
      const limit = req.query.limit ? parseInt(req.query.limit, 10) : 10;

      if (!departmentId) {
        return res.status(400).json({
          success: false,
          message: 'department_id is required'
        });
      }

      const topPerformers = await PerformanceService.getTopPerformers(departmentId, limit);

      res.json({
        success: true,
        data: topPerformers
      });
    } catch (error) {
      logger.error('Get top performers error:', error);
      next(error);
    }
  }

  /**
   * POST /api/v1/hr/performance-report
   * Generate and return comprehensive HR report
   */
  static async generatePerformanceReport(req, res, next) {
    try {
      const canAccess = await RBACService.canAccessPerformanceData(req.user);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const { month, year, format } = req.body;

      if (!month || !year) {
        return res.status(400).json({
          success: false,
          message: 'month and year are required'
        });
      }

      const report = await PerformanceService.generateHRReport(month, year);

      // If format is JSON, return as is
      if (format === 'json') {
        return res.json({
          success: true,
          data: report
        });
      }

      // Otherwise, send as downloadable attachment (CSV or JSON file)
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename="hr-report-${year}-${month}.json"`);
      res.send(JSON.stringify(report, null, 2));
    } catch (error) {
      logger.error('Generate performance report error:', error);
      next(error);
    }
  }

  /**
   * GET /api/v1/hr/performance-summary
   * Quick summary of all performance metrics
   */
  static async getPerformanceSummary(req, res, next) {
    try {
      const canAccess = await RBACService.canAccessPerformanceData(req.user);
      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'Access denied.'
        });
      }

      const currentDate = new Date();
      const month = req.query.month || currentDate.getMonth() + 1;
      const year = req.query.year || currentDate.getFullYear();

      // Generate full report
      const report = await PerformanceService.generateHRReport(month, year);

      // Return summary with top stats
      const summary = {
        period: `${month}/${year}`,
        generated_at: new Date(),
        company_summary: report.company_summary,
        top_departments: report.departments
          .sort((a, b) => b.completion_percentage - a.completion_percentage)
          .slice(0, 3)
      };

      res.json({
        success: true,
        data: summary
      });
    } catch (error) {
      logger.error('Get performance summary error:', error);
      next(error);
    }
  }
}

module.exports = PerformanceController;
