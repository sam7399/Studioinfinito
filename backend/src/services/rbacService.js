const { User, Task, Department } = require('../models');
const { Op } = require('sequelize');

/**
 * RBAC Service - Handles role-based access control and privacy masking
 */
class RBACService {
  /**
   * Get user's accessible user IDs based on role
   */
  static async getAccessibleUserIds(user) {
    switch (user.role) {
      case 'superadmin':
        // Superadmin can see all users
        const allUsers = await User.findAll({ attributes: ['id'] });
        return allUsers.map(u => u.id);

      case 'management':
        // Management can see all users in their company
        if (!user.company_id) return [user.id];
        const companyUsers = await User.findAll({
          where: { company_id: user.company_id },
          attributes: ['id']
        });
        return companyUsers.map(u => u.id);

      case 'department_head':
        // Department head can see users in their department
        if (!user.department_id) return [user.id];
        const deptUsers = await User.findAll({
          where: { department_id: user.department_id },
          attributes: ['id']
        });
        return deptUsers.map(u => u.id);

      case 'manager':
        // Manager can see their team members + self
        const teamMembers = await User.findAll({
          where: { manager_id: user.id },
          attributes: ['id']
        });
        return [user.id, ...teamMembers.map(u => u.id)];

      case 'employee':
      default:
        // Employee can only see self
        return [user.id];
    }
  }

  /**
   * Get task visibility scope for user.
   * All roles see all tasks in their company (cross-dept privacy masking applied after fetch).
   * If no company_id, fall back to own tasks only.
   */
  static async getTaskVisibilityScope(user) {
    if (user.role === 'superadmin') return {};

    // Users with a company see all tasks in that company
    if (user.company_id) {
      return { company_id: user.company_id };
    }

    // No company assigned — only own tasks
    return {
      [Op.or]: [
        { created_by_user_id: user.id },
        { assigned_to_user_id: user.id }
      ]
    };
  }

  /**
   * Check if user can view task details.
   * All company members can view any company task (privacy masking applied at service layer).
   */
  static async canViewTask(user, task) {
    if (user.role === 'superadmin') return true;
    if (user.company_id && task.company_id === user.company_id) return true;

    // Fallback: own tasks
    return (
      task.created_by_user_id === user.id ||
      task.assigned_to_user_id === user.id
    );
  }

  /**
   * Check if user can edit task
   */
  static async canEditTask(user, task) {
    // Superadmin and management can edit any task in their scope
    if (['superadmin', 'management'].includes(user.role)) {
      if (user.role === 'superadmin') return true;
      return task.company_id === user.company_id;
    }

    // Department head can edit tasks in their department
    if (user.role === 'department_head') {
      return task.department_id === user.department_id;
    }

    // Manager can edit tasks for their team
    if (user.role === 'manager') {
      const accessibleUserIds = await this.getAccessibleUserIds(user);
      return (
        accessibleUserIds.includes(task.created_by_user_id) ||
        accessibleUserIds.includes(task.assigned_to_user_id)
      );
    }

    // Employee can edit their own tasks
    return task.assigned_to_user_id === user.id || task.created_by_user_id === user.id;
  }

  /**
   * Check if user can delete task
   */
  static async canDeleteTask(user, task) {
    // Only superadmin and management can delete
    if (user.role === 'superadmin') return true;
    if (user.role === 'management' && task.company_id === user.company_id) return true;
    return false;
  }

  /**
   * Check if user can review task
   */
  static async canReviewTask(user, task) {
    // Task creator or their manager can review
    if (task.created_by_user_id === user.id) return true;

    // Check if user is manager of the task creator
    const creator = await User.findByPk(task.created_by_user_id);
    if (creator && creator.manager_id === user.id) return true;

    // Management and department heads can review tasks in their scope
    if (user.role === 'management' && task.company_id === user.company_id) return true;
    if (user.role === 'department_head' && task.department_id === user.department_id) return true;

    return false;
  }

  /**
   * Apply privacy masking to task
   */
  static async maskTask(user, task) {
    const canView = await this.canViewTask(user, task);

    if (canView) {
      return task; // Return full task data
    }

    // Return masked task
    return {
      id: task.id,
      title: '[Restricted]',
      description: null,
      status: task.status,
      priority: task.priority,
      due_date: task.due_date,
      progress_percent: task.progress_percent,
      created_at: task.created_at,
      updated_at: task.updated_at,
      completed_at: task.completed_at,
      // Include department and location names but not user details
      department: task.department ? { id: task.department.id, name: task.department.name } : null,
      location: task.location ? { id: task.location.id, name: task.location.name } : null,
      // Mask user information
      creator: null,
      assignee: null,
      company: null
    };
  }

  /**
   * Apply privacy masking to array of tasks
   */
  static async maskTasks(user, tasks) {
    return Promise.all(tasks.map(task => this.maskTask(user, task)));
  }

  /**
   * Check if user can access company data
   */
  static canAccessCompany(user, companyId) {
    if (user.role === 'superadmin') return true;
    return user.company_id === parseInt(companyId, 10);
  }

  /**
   * Get company scope for queries
   */
  static getCompanyScope(user, requestedCompanyId = null) {
    if (user.role === 'superadmin') {
      return requestedCompanyId ? { company_id: requestedCompanyId } : {};
    }
    return { company_id: user.company_id };
  }
}

module.exports = RBACService;