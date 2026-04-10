const { Task, TaskApproval, User, TaskActivity, Department, sequelize } = require('../models');
const { Op } = require('sequelize');
const RBACService = require('./rbacService');
const NotificationService = require('./notificationService');
const logger = require('../utils/logger');

class ApprovalService {
  /**
   * Submit a completed task for approval
   * Only the assigned user or task creator can submit for approval
   * Task must be in 'complete_pending_review' status
   *
   * @param {number} taskId - Task ID
   * @param {number} userId - User ID submitting for approval
   * @returns {Object} Updated task with approval status
   */
  static async submitForApproval(taskId, userId) {
    // BUG-004 FIX: Wrap in database transaction for atomicity
    const transaction = await sequelize.transaction();
    try {
      const task = await Task.findByPk(taskId, {
        include: [
          { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
          { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        transaction
      });

      if (!task) {
        await transaction.rollback();
        throw new Error('Task not found');
      }

      // Check if user has permission to submit for approval
      // Only creator or assignee can submit
      if (task.created_by_user_id !== userId && task.assigned_to_user_id !== userId) {
        await transaction.rollback();
        throw new Error('Only task creator or assignee can submit for approval');
      }

      // Task must be in complete_pending_review status
      if (task.status !== 'complete_pending_review') {
        await transaction.rollback();
        throw new Error(`Task cannot be submitted for approval from '${task.status}' status`);
      }

      // Task should not already be pending approval
      if (task.approval_status === 'pending') {
        await transaction.rollback();
        throw new Error('Task is already pending approval');
      }

      // Find the appropriate approver (department manager or department head)
      const approver = await this._findApproverForTask(task);
      if (!approver) {
        await transaction.rollback();
        throw new Error('No eligible approver found for this task');
      }

      // Update task with approval_status = 'pending'
      task.approval_status = 'pending';
      task.approver_id = approver.id;
      await task.save({ transaction });

      // Create TaskApproval record
      const approval = await TaskApproval.create({
        task_id: taskId,
        approver_id: approver.id,
        status: 'pending',
        submitted_at: new Date()
      }, { transaction });

      // Log activity
      await TaskActivity.create({
        task_id: taskId,
        actor_user_id: userId,
        action: 'submitted_for_approval',
        note: `Task submitted for approval to ${approver.name}`
      }, { transaction });

      // Commit transaction before sending notifications (notifications are non-critical)
      await transaction.commit();

      // Send notification to approver (outside transaction - non-critical)
      try {
        await NotificationService.notifyTaskSubmittedForApproval(
          taskId,
          approver.id,
          task.title,
          userId
        );
      } catch (notifError) {
        logger.warn('Failed to send approval submission notification:', notifError.message);
      }

      return {
        ...task.toJSON(),
        approver: approver,
        approval: approval.toJSON()
      };
    } catch (error) {
      // Rollback only if transaction hasn't been committed yet
      if (!transaction.finished) {
        await transaction.rollback();
      }
      logger.error('Error submitting task for approval:', error);
      throw error;
    }
  }

  /**
   * Get all tasks pending approval for a manager
   *
   * @param {number} managerId - Manager user ID
   * @param {Object} options - Pagination and filter options
   * @returns {Object} Paginated list of pending tasks
   */
  static async getTasksForApproval(managerId, options = {}) {
    try {
      const { page = 1, limit = 20, status = 'pending', priority, department_id } = options;
      const offset = (page - 1) * limit;

      // Verify that the user is a manager or department head
      const user = await User.findByPk(managerId);
      if (!user) {
        throw new Error('User not found');
      }

      const isApprover = ['manager', 'department_head', 'superadmin', 'management'].includes(user.role);
      if (!isApprover) {
        throw new Error('Only managers and department heads can approve tasks');
      }

      // BUG-003 FIX: Use 'status' (the actual column in task_approvals table) instead of 'approval_status'
      // BUG-012 FIX: Filter by approver_id so managers only see approvals assigned to them
      const where = { status: status };

      // Filter by approver_id for managers; superadmin/management can see all
      if (user.role === 'manager' || user.role === 'department_head') {
        where.approver_id = managerId;
      }

      const taskWhere = {};

      // If department_id is specified, filter by that department
      if (department_id) {
        taskWhere.department_id = department_id;
      }

      // If manager (not department head), only show tasks from their department
      if (user.role === 'manager') {
        taskWhere.department_id = user.department_id;
      }

      if (priority) {
        taskWhere.priority = priority;
      }

      // Query pending approvals for this approver
      const { count, rows } = await TaskApproval.findAndCountAll({
        where,
        include: [
          {
            model: Task,
            as: 'task',
            where: Object.keys(taskWhere).length > 0 ? taskWhere : undefined,
            include: [
              { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
              { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
              { model: Department, as: 'department', attributes: ['id', 'name'] }
            ]
          },
          { model: User, as: 'approver', attributes: ['id', 'name', 'email'] }
        ],
        order: [['created_at', 'DESC']],
        limit,
        offset
      });

      return {
        data: rows.map(approval => ({
          ...approval.toJSON(),
          task: approval.task ? approval.task.toJSON() : null
        })),
        pagination: {
          page,
          limit,
          total: count,
          pages: Math.ceil(count / limit)
        }
      };
    } catch (error) {
      logger.error('Error getting tasks for approval:', error);
      throw error;
    }
  }

  /**
   * Approve a task
   *
   * @param {number} taskId - Task ID
   * @param {number} approverId - User ID of the approver
   * @param {string} comments - Optional approval comments
   * @returns {Object} Updated task and approval record
   */
  static async approveTask(taskId, approverId, comments = null) {
    // BUG-004 FIX: Wrap in database transaction for atomicity
    const transaction = await sequelize.transaction();
    try {
      const task = await Task.findByPk(taskId, {
        include: [
          { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
          { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        transaction
      });

      if (!task) {
        await transaction.rollback();
        throw new Error('Task not found');
      }

      // Check if task is pending approval
      if (task.approval_status !== 'pending') {
        await transaction.rollback();
        throw new Error(`Task cannot be approved from '${task.approval_status}' status`);
      }

      // Check if approver has permission
      const approver = await User.findByPk(approverId, { transaction });
      if (!approver) {
        await transaction.rollback();
        throw new Error('Approver user not found');
      }

      // Verify approver is eligible to approve this task
      const isEligible = await this._isEligibleApprover(approverId, task);
      if (!isEligible) {
        await transaction.rollback();
        throw new Error('User is not eligible to approve this task');
      }

      // Find or create the approval record
      let approval = await TaskApproval.findOne({
        where: {
          task_id: taskId,
          approver_id: approverId
        },
        transaction
      });

      if (!approval) {
        // Create a new approval record if it doesn't exist
        approval = await TaskApproval.create({
          task_id: taskId,
          approver_id: approverId,
          status: 'approved',
          comments,
          reviewed_at: new Date()
        }, { transaction });
      } else {
        // Update existing approval record
        approval.status = 'approved';
        approval.comments = comments;
        approval.reviewed_at = new Date();
        await approval.save({ transaction });
      }

      // Update task
      task.approval_status = 'approved';
      task.approver_id = approverId;
      task.approval_comments = comments;
      task.approval_date = new Date();
      task.status = 'finalized';
      await task.save({ transaction });

      // Log activity
      await TaskActivity.create({
        task_id: taskId,
        actor_user_id: approverId,
        action: 'approved',
        note: comments || 'Task approved'
      }, { transaction });

      // Commit transaction before sending notifications
      await transaction.commit();

      // Send notifications (outside transaction - non-critical)
      try {
        await NotificationService.notifyTaskApproved(taskId, task.title, approverId);
      } catch (notifError) {
        logger.warn('Failed to send approval notification:', notifError.message);
      }

      return {
        task: task.toJSON(),
        approval: approval.toJSON()
      };
    } catch (error) {
      if (!transaction.finished) {
        await transaction.rollback();
      }
      logger.error('Error approving task:', error);
      throw error;
    }
  }

  /**
   * Reject a task
   * Rejects the task and returns it to 'in_progress' status
   *
   * @param {number} taskId - Task ID
   * @param {number} approverId - User ID of the approver
   * @param {string} reason - Reason for rejection
   * @returns {Object} Updated task and approval record
   */
  static async rejectTask(taskId, approverId, reason) {
    // BUG-004 FIX: Wrap in database transaction for atomicity
    const transaction = await sequelize.transaction();
    try {
      if (!reason || reason.trim().length === 0) {
        await transaction.rollback();
        throw new Error('Rejection reason is required');
      }

      const task = await Task.findByPk(taskId, {
        include: [
          { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
          { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        transaction
      });

      if (!task) {
        await transaction.rollback();
        throw new Error('Task not found');
      }

      // Check if task is pending approval
      if (task.approval_status !== 'pending') {
        await transaction.rollback();
        throw new Error(`Task cannot be rejected from '${task.approval_status}' status`);
      }

      // Check if approver has permission
      const approver = await User.findByPk(approverId, { transaction });
      if (!approver) {
        await transaction.rollback();
        throw new Error('Approver user not found');
      }

      // Verify approver is eligible to reject this task
      const isEligible = await this._isEligibleApprover(approverId, task);
      if (!isEligible) {
        await transaction.rollback();
        throw new Error('User is not eligible to reject this task');
      }

      // Find or create the approval record
      let approval = await TaskApproval.findOne({
        where: {
          task_id: taskId,
          approver_id: approverId
        },
        transaction
      });

      if (!approval) {
        approval = await TaskApproval.create({
          task_id: taskId,
          approver_id: approverId,
          status: 'rejected',
          reason,
          reviewed_at: new Date()
        }, { transaction });
      } else {
        approval.status = 'rejected';
        approval.reason = reason;
        approval.reviewed_at = new Date();
        await approval.save({ transaction });
      }

      // Update task - return to in_progress
      task.approval_status = 'rejected';
      task.approver_id = approverId;
      task.rejection_reason = reason;
      task.approval_date = new Date();
      task.status = 'in_progress'; // Return to in_progress for rework
      await task.save({ transaction });

      // BUG-005 FIX: Log activity as 'rejected' instead of 'reopened'
      await TaskActivity.create({
        task_id: taskId,
        actor_user_id: approverId,
        action: 'rejected',
        note: `Task rejected: ${reason}`
      }, { transaction });

      // Commit transaction before sending notifications
      await transaction.commit();

      // Send notifications (outside transaction - non-critical)
      try {
        await NotificationService.notifyTaskRejected(taskId, task.title, approverId, reason);
      } catch (notifError) {
        logger.warn('Failed to send rejection notification:', notifError.message);
      }

      return {
        task: task.toJSON(),
        approval: approval.toJSON()
      };
    } catch (error) {
      if (!transaction.finished) {
        await transaction.rollback();
      }
      logger.error('Error rejecting task:', error);
      throw error;
    }
  }

  /**
   * Get approval history for a task
   *
   * @param {number} taskId - Task ID
   * @returns {Array} List of all approvals for this task (audit trail)
   */
  static async getApprovalHistory(taskId) {
    try {
      const task = await Task.findByPk(taskId);
      if (!task) {
        throw new Error('Task not found');
      }

      const approvals = await TaskApproval.findAll({
        where: { task_id: taskId },
        include: [
          { model: User, as: 'approver', attributes: ['id', 'name', 'email'] }
        ],
        order: [['created_at', 'DESC']]
      });

      return approvals.map(approval => approval.toJSON());
    } catch (error) {
      logger.error('Error getting approval history:', error);
      throw error;
    }
  }

  /**
   * Get pending approvals count for a manager
   *
   * @param {number} managerId - Manager user ID
   * @returns {number} Count of pending approvals
   */
  static async getPendingApprovalsCount(managerId) {
    try {
      const user = await User.findByPk(managerId);
      if (!user) {
        throw new Error('User not found');
      }

      // BUG-003 FIX: Use 'status' (the actual column in task_approvals table) instead of 'approval_status'
      // BUG-012 FIX: Filter by approver_id so managers only see their own pending count
      const where = { status: 'pending' };

      // Filter by approver_id for managers/dept heads
      if (user.role === 'manager' || user.role === 'department_head') {
        where.approver_id = managerId;
      }

      const taskWhere = {};

      if (user.role === 'manager' || user.role === 'department_head') {
        taskWhere.department_id = user.department_id;
      }

      const count = await TaskApproval.count({
        where,
        include: [
          {
            model: Task,
            as: 'task',
            where: Object.keys(taskWhere).length > 0 ? taskWhere : undefined
          }
        ]
      });

      return count;
    } catch (error) {
      logger.error('Error getting pending approvals count:', error);
      throw error;
    }
  }

  /**
   * Internal method: Find the appropriate approver for a task
   * 1. First, try to find the department manager
   * 2. If no manager, use the department head
   * 3. If no department head, use company management/superadmin
   *
   * @private
   * @param {Object} task - Task object
   * @returns {Object} User object of the approver
   */
  static async _findApproverForTask(task) {
    try {
      // First, try to find the department manager
      const manager = await User.findOne({
        where: {
          department_id: task.department_id,
          role: 'manager',
          deleted_at: null
        }
      });

      if (manager) {
        return manager;
      }

      // If no manager, find department head
      const deptHead = await User.findOne({
        where: {
          department_id: task.department_id,
          role: 'department_head',
          deleted_at: null
        }
      });

      if (deptHead) {
        return deptHead;
      }

      // If no department head, find company management
      const management = await User.findOne({
        where: {
          company_id: task.company_id,
          role: 'management',
          deleted_at: null
        }
      });

      return management;
    } catch (error) {
      logger.error('Error finding approver for task:', error);
      return null;
    }
  }

  /**
   * Internal method: Check if a user is eligible to approve a task
   * A user can approve a task if:
   * - They are the department manager or department head for the task's department
   * - Or they are management/superadmin for the company
   * - And they respect department privacy rules
   *
   * @private
   * @param {number} userId - User ID
   * @param {Object} task - Task object
   * @returns {boolean} True if user can approve the task
   */
  static async _isEligibleApprover(userId, task) {
    try {
      const user = await User.findByPk(userId);
      if (!user) {
        return false;
      }

      // Superadmin can approve any task
      if (user.role === 'superadmin') {
        return true;
      }

      // Management can approve any task in their company
      if (user.role === 'management' && user.company_id === task.company_id) {
        return true;
      }

      // Department head or manager can approve tasks in their department
      if (
        (user.role === 'department_head' || user.role === 'manager') &&
        user.department_id === task.department_id &&
        user.company_id === task.company_id
      ) {
        return true;
      }

      return false;
    } catch (error) {
      logger.error('Error checking if user is eligible approver:', error);
      return false;
    }
  }
}

module.exports = ApprovalService;
