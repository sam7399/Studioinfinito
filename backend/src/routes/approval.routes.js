const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const approvalController = require('../controllers/approvalController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// All approval routes require authentication
router.use(authenticate);

/**
 * POST /api/v1/tasks/:id/submit-for-approval
 * Submit a completed task for approval
 * Allowed: Task creator, Task assignee
 */
router.post(
  '/:id/submit-for-approval',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  approvalController.submitForApproval
);

/**
 * GET /api/v1/manager/pending-approvals
 * Get all tasks pending approval for the current manager
 * Allowed: Managers, Department heads, Management, Superadmin
 */
router.get(
  '/manager/pending-approvals',
  celebrate({
    [Segments.QUERY]: Joi.object({
      page: Joi.number().integer().min(1).default(1),
      limit: Joi.number().integer().min(1).max(100).default(20),
      priority: Joi.string().valid('low', 'normal', 'high', 'urgent'),
      department_id: Joi.number().integer()
    })
  }),
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  approvalController.getPendingApprovals
);

/**
 * GET /api/v1/manager/pending-approvals-count
 * Get count of pending approvals for the current manager
 * Allowed: Managers, Department heads, Management, Superadmin
 */
router.get(
  '/manager/pending-approvals-count',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  approvalController.getPendingApprovalsCount
);

/**
 * PUT /api/v1/tasks/:id/approve
 * Approve a task
 * Allowed: Managers, Department heads, Management, Superadmin
 */
router.put(
  '/:id/approve',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      comments: Joi.string().allow('', null).optional()
    })
  }),
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  approvalController.approveTask
);

/**
 * PUT /api/v1/tasks/:id/reject
 * Reject a task (returns task to in_progress status)
 * Allowed: Managers, Department heads, Management, Superadmin
 */
router.put(
  '/:id/reject',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      reason: Joi.string().required().min(1).max(1000)
    })
  }),
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  approvalController.rejectTask
);

/**
 * GET /api/v1/tasks/:id/approval-history
 * Get approval audit trail for a task
 * Allowed: All authenticated users (respects task privacy rules)
 */
router.get(
  '/:id/approval-history',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  approvalController.getApprovalHistory
);

module.exports = router;
