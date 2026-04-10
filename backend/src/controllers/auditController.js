const AuditService = require('../services/auditService');
const logger = require('../utils/logger');

class AuditController {
  static async getCompletionCycles(req, res, next) {
    try {
      const data = await AuditService.getCompletionCycles(req.query);
      res.json({ success: true, data });
    } catch (error) {
      logger.error('Get completion cycles error:', error);
      next(error);
    }
  }

  static async getReopenFrequency(req, res, next) {
    try {
      const data = await AuditService.getReopenFrequency(req.query);
      res.json({ success: true, data });
    } catch (error) {
      logger.error('Get reopen frequency error:', error);
      next(error);
    }
  }

  static async getApprovalTimelines(req, res, next) {
    try {
      const data = await AuditService.getApprovalTimelines(req.query);
      res.json({ success: true, data });
    } catch (error) {
      logger.error('Get approval timelines error:', error);
      next(error);
    }
  }

  static async getHRDashboard(req, res, next) {
    try {
      const data = await AuditService.getHRDashboard(req.query);
      res.json({ success: true, data });
    } catch (error) {
      logger.error('Get HR dashboard error:', error);
      next(error);
    }
  }
}

module.exports = AuditController;
