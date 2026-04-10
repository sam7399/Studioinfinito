const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const AuditController = require('../controllers/auditController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// All audit routes require authentication and management-level roles
router.use(authenticate);
router.use(requireRole('superadmin', 'management', 'department_head'));

const dateFilterSchema = {
  [Segments.QUERY]: Joi.object({
    startDate: Joi.date().iso(),
    endDate: Joi.date().iso(),
    departmentId: Joi.number().integer(),
    userId: Joi.number().integer(),
    approverId: Joi.number().integer(),
    minReopens: Joi.number().integer().min(0)
  })
};

// Completion cycle metrics
router.get('/completion-cycles', celebrate(dateFilterSchema), AuditController.getCompletionCycles);

// Reopen frequency metrics
router.get('/reopen-frequency', celebrate(dateFilterSchema), AuditController.getReopenFrequency);

// Approval timeline metrics
router.get('/approval-timelines', celebrate(dateFilterSchema), AuditController.getApprovalTimelines);

// Combined HR dashboard
router.get('/dashboard', celebrate(dateFilterSchema), AuditController.getHRDashboard);

module.exports = router;
