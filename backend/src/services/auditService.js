const { Task, TaskActivity, TaskApproval, User, Department, sequelize } = require('../models');
const { Op, fn, col, literal } = require('sequelize');
const logger = require('../utils/logger');

/**
 * AuditService — structured data for HR metrics queries.
 * Provides completion cycles, reopen frequency, and approval timelines.
 */
class AuditService {

  /**
   * Get completion cycle metrics for tasks in a date range.
   * Cycle = time from task creation to first completion.
   */
  static async getCompletionCycles({ startDate, endDate, departmentId, userId } = {}) {
    try {
      const where = {};
      if (startDate || endDate) {
        where.created_at = {};
        if (startDate) where.created_at[Op.gte] = new Date(startDate);
        if (endDate) where.created_at[Op.lte] = new Date(endDate);
      }
      if (departmentId) where.department_id = departmentId;
      if (userId) where.assigned_to_user_id = userId;

      // Only tasks that have been completed at least once
      where.first_completed_at = { [Op.ne]: null };

      const tasks = await Task.findAll({
        where,
        attributes: [
          'id', 'title', 'status', 'created_at', 'first_completed_at',
          'completed_at', 'reopen_count', 'department_id', 'assigned_to_user_id'
        ],
        include: [
          { model: User, as: 'assignee', attributes: ['id', 'name'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        order: [['created_at', 'DESC']]
      });

      const metrics = tasks.map(t => {
        const created = new Date(t.created_at);
        const firstCompleted = new Date(t.first_completed_at);
        const cycleHours = (firstCompleted - created) / (1000 * 60 * 60);
        return {
          task_id: t.id,
          title: t.title,
          status: t.status,
          assignee: t.assignee ? { id: t.assignee.id, name: t.assignee.name } : null,
          department: t.department ? { id: t.department.id, name: t.department.name } : null,
          created_at: t.created_at,
          first_completed_at: t.first_completed_at,
          cycle_hours: Math.round(cycleHours * 10) / 10,
          cycle_days: Math.round((cycleHours / 24) * 10) / 10,
          reopen_count: t.reopen_count || 0
        };
      });

      // Summary statistics
      const cycleHoursArr = metrics.map(m => m.cycle_hours);
      const summary = {
        total_tasks: metrics.length,
        avg_cycle_hours: cycleHoursArr.length ? Math.round((cycleHoursArr.reduce((a, b) => a + b, 0) / cycleHoursArr.length) * 10) / 10 : 0,
        min_cycle_hours: cycleHoursArr.length ? Math.min(...cycleHoursArr) : 0,
        max_cycle_hours: cycleHoursArr.length ? Math.max(...cycleHoursArr) : 0,
        avg_cycle_days: cycleHoursArr.length ? Math.round((cycleHoursArr.reduce((a, b) => a + b, 0) / cycleHoursArr.length / 24) * 10) / 10 : 0
      };

      return { summary, tasks: metrics };
    } catch (error) {
      logger.error('Error getting completion cycles:', error);
      throw error;
    }
  }

  /**
   * Get reopen frequency metrics — which tasks are being reopened most often.
   */
  static async getReopenFrequency({ startDate, endDate, departmentId, minReopens = 0 } = {}) {
    try {
      const where = { reopen_count: { [Op.gt]: minReopens } };
      if (startDate || endDate) {
        where.created_at = {};
        if (startDate) where.created_at[Op.gte] = new Date(startDate);
        if (endDate) where.created_at[Op.lte] = new Date(endDate);
      }
      if (departmentId) where.department_id = departmentId;

      const tasks = await Task.findAll({
        where,
        attributes: [
          'id', 'title', 'status', 'reopen_count', 'last_reopened_at',
          'created_at', 'department_id', 'assigned_to_user_id', 'created_by_user_id'
        ],
        include: [
          { model: User, as: 'assignee', attributes: ['id', 'name'] },
          { model: User, as: 'creator', attributes: ['id', 'name'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        order: [['reopen_count', 'DESC']]
      });

      // Get reopen activities with comments for each task
      const taskIds = tasks.map(t => t.id);
      const reopenActivities = taskIds.length ? await TaskActivity.findAll({
        where: { task_id: { [Op.in]: taskIds }, action: 'reopened' },
        include: [{ model: User, as: 'actor', attributes: ['id', 'name'] }],
        order: [['created_at', 'DESC']]
      }) : [];

      const activityByTask = {};
      reopenActivities.forEach(a => {
        if (!activityByTask[a.task_id]) activityByTask[a.task_id] = [];
        activityByTask[a.task_id].push({
          reopened_by: a.actor ? { id: a.actor.id, name: a.actor.name } : null,
          comment: a.note,
          reopened_at: a.created_at
        });
      });

      const metrics = tasks.map(t => ({
        task_id: t.id,
        title: t.title,
        status: t.status,
        reopen_count: t.reopen_count,
        last_reopened_at: t.last_reopened_at,
        assignee: t.assignee ? { id: t.assignee.id, name: t.assignee.name } : null,
        creator: t.creator ? { id: t.creator.id, name: t.creator.name } : null,
        department: t.department ? { id: t.department.id, name: t.department.name } : null,
        reopen_history: activityByTask[t.id] || []
      }));

      const summary = {
        total_reopened_tasks: metrics.length,
        total_reopens: metrics.reduce((sum, m) => sum + m.reopen_count, 0),
        avg_reopens_per_task: metrics.length ? Math.round((metrics.reduce((sum, m) => sum + m.reopen_count, 0) / metrics.length) * 10) / 10 : 0,
        max_reopens: metrics.length ? Math.max(...metrics.map(m => m.reopen_count)) : 0
      };

      return { summary, tasks: metrics };
    } catch (error) {
      logger.error('Error getting reopen frequency:', error);
      throw error;
    }
  }

  /**
   * Get approval timeline metrics — time from submission to approval/rejection.
   */
  static async getApprovalTimelines({ startDate, endDate, departmentId, approverId } = {}) {
    try {
      const where = {};
      if (startDate || endDate) {
        where.submitted_at = {};
        if (startDate) where.submitted_at[Op.gte] = new Date(startDate);
        if (endDate) where.submitted_at[Op.lte] = new Date(endDate);
      }
      if (approverId) where.approver_id = approverId;
      // Only resolved approvals
      where.status = { [Op.in]: ['approved', 'rejected'] };
      where.reviewed_at = { [Op.ne]: null };

      const approvals = await TaskApproval.findAll({
        where,
        include: [
          {
            model: Task, as: 'task',
            attributes: ['id', 'title', 'department_id'],
            where: departmentId ? { department_id: departmentId } : {},
            include: [{ model: Department, as: 'department', attributes: ['id', 'name'] }]
          },
          { model: User, as: 'approver', attributes: ['id', 'name'] }
        ],
        order: [['submitted_at', 'DESC']]
      });

      const metrics = approvals.map(a => {
        const submitted = new Date(a.submitted_at);
        const reviewed = new Date(a.reviewed_at);
        const responseHours = (reviewed - submitted) / (1000 * 60 * 60);
        return {
          approval_id: a.id,
          task_id: a.task_id,
          task_title: a.task ? a.task.title : null,
          department: a.task?.department ? { id: a.task.department.id, name: a.task.department.name } : null,
          approver: a.approver ? { id: a.approver.id, name: a.approver.name } : null,
          status: a.status,
          submitted_at: a.submitted_at,
          reviewed_at: a.reviewed_at,
          response_hours: Math.round(responseHours * 10) / 10,
          response_days: Math.round((responseHours / 24) * 10) / 10,
          comments: a.comments,
          reason: a.reason
        };
      });

      const responseHoursArr = metrics.map(m => m.response_hours);
      const approvedCount = metrics.filter(m => m.status === 'approved').length;
      const rejectedCount = metrics.filter(m => m.status === 'rejected').length;

      const summary = {
        total_approvals: metrics.length,
        approved_count: approvedCount,
        rejected_count: rejectedCount,
        approval_rate: metrics.length ? Math.round((approvedCount / metrics.length) * 100) : 0,
        avg_response_hours: responseHoursArr.length ? Math.round((responseHoursArr.reduce((a, b) => a + b, 0) / responseHoursArr.length) * 10) / 10 : 0,
        avg_response_days: responseHoursArr.length ? Math.round((responseHoursArr.reduce((a, b) => a + b, 0) / responseHoursArr.length / 24) * 10) / 10 : 0,
        min_response_hours: responseHoursArr.length ? Math.min(...responseHoursArr) : 0,
        max_response_hours: responseHoursArr.length ? Math.max(...responseHoursArr) : 0
      };

      return { summary, approvals: metrics };
    } catch (error) {
      logger.error('Error getting approval timelines:', error);
      throw error;
    }
  }

  /**
   * Get combined HR metrics dashboard data.
   */
  static async getHRDashboard(params = {}) {
    try {
      const [completionCycles, reopenFrequency, approvalTimelines] = await Promise.all([
        this.getCompletionCycles(params),
        this.getReopenFrequency(params),
        this.getApprovalTimelines(params)
      ]);

      return {
        completion_cycles: completionCycles,
        reopen_frequency: reopenFrequency,
        approval_timelines: approvalTimelines,
        generated_at: new Date()
      };
    } catch (error) {
      logger.error('Error generating HR dashboard:', error);
      throw error;
    }
  }
}

module.exports = AuditService;
