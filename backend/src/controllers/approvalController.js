const ApprovalService = require('../services/approvalService');
const logger = require('../utils/logger');

class ApprovalController {
  /**
   * POST /api/v1/tasks/:id/submit-for-approval
   * Submit a completed task for approval
   */
  static async submitForApproval(req, res) {
    try {
      const { id: taskId } = req.params;
      const userId = req.user.id;

      const result = await ApprovalService.submitForApproval(taskId, userId);

      return res.status(200).json({
        success: true,
        message: 'Task submitted for approval',
        data: result
      });
    } catch (error) {
      logger.error('Error submitting task for approval:', error);

      if (error.message.includes('not found') || error.message.includes('cannot be submitted')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      if (error.message.includes('permission') || error.message.includes('not eligible')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error submitting task for approval'
      });
    }
  }

  /**
   * GET /api/v1/manager/pending-approvals
   * Get all tasks waiting for approval for the current manager
   */
  static async getPendingApprovals(req, res) {
    try {
      const managerId = req.user.id;
      const { page = 1, limit = 20, priority, department_id } = req.query;

      const result = await ApprovalService.getTasksForApproval(managerId, {
        page: parseInt(page),
        limit: parseInt(limit),
        priority,
        department_id: department_id ? parseInt(department_id) : undefined
      });

      return res.status(200).json({
        success: true,
        message: 'Pending approvals retrieved',
        data: result.data,
        pagination: result.pagination
      });
    } catch (error) {
      logger.error('Error getting pending approvals:', error);

      if (error.message.includes('not') || error.message.includes('only')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error retrieving pending approvals'
      });
    }
  }

  /**
   * PUT /api/v1/tasks/:id/approve
   * Approve a task
   */
  static async approveTask(req, res) {
    try {
      const { id: taskId } = req.params;
      const { comments } = req.body;
      const approverId = req.user.id;

      const result = await ApprovalService.approveTask(taskId, approverId, comments);

      return res.status(200).json({
        success: true,
        message: 'Task approved successfully',
        data: result
      });
    } catch (error) {
      logger.error('Error approving task:', error);

      if (error.message.includes('not found') || error.message.includes('cannot be approved')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      if (error.message.includes('not eligible') || error.message.includes('permission')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error approving task'
      });
    }
  }

  /**
   * PUT /api/v1/tasks/:id/reject
   * Reject a task
   */
  static async rejectTask(req, res) {
    try {
      const { id: taskId } = req.params;
      const { reason } = req.body;
      const approverId = req.user.id;

      // Validate that reason is provided
      if (!reason || reason.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Rejection reason is required'
        });
      }

      const result = await ApprovalService.rejectTask(taskId, approverId, reason);

      return res.status(200).json({
        success: true,
        message: 'Task rejected successfully',
        data: result
      });
    } catch (error) {
      logger.error('Error rejecting task:', error);

      if (error.message.includes('not found') || error.message.includes('cannot be rejected')) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      if (error.message.includes('not eligible') || error.message.includes('permission')) {
        return res.status(403).json({
          success: false,
          message: error.message
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error rejecting task'
      });
    }
  }

  /**
   * GET /api/v1/tasks/:id/approval-history
   * Get approval audit trail for a task
   */
  static async getApprovalHistory(req, res) {
    try {
      const { id: taskId } = req.params;

      const history = await ApprovalService.getApprovalHistory(taskId);

      return res.status(200).json({
        success: true,
        message: 'Approval history retrieved',
        data: history
      });
    } catch (error) {
      logger.error('Error getting approval history:', error);

      if (error.message.includes('not found')) {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error retrieving approval history'
      });
    }
  }

  /**
   * GET /api/v1/manager/pending-approvals-count
   * Get count of pending approvals for current manager
   */
  static async getPendingApprovalsCount(req, res) {
    try {
      const managerId = req.user.id;

      const count = await ApprovalService.getPendingApprovalsCount(managerId);

      return res.status(200).json({
        success: true,
        message: 'Pending approvals count retrieved',
        data: {
          count
        }
      });
    } catch (error) {
      logger.error('Error getting pending approvals count:', error);

      return res.status(500).json({
        success: false,
        message: 'Error retrieving pending approvals count'
      });
    }
  }
}

module.exports = ApprovalController;
