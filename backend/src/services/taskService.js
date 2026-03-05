const { Task, User, Department, Location, Company, TaskActivity, TaskReview } = require('../models');
const { Op } = require('sequelize');
const RBACService = require('./rbacService');
const logger = require('../utils/logger');
const Mailer = require('../mail/mailer');

class TaskService {
  /**
   * List tasks with filters and pagination
   */
  static async listTasks(filters, user) {
    const {
      page = 1,
      limit = 20,
      status,
      priority,
      assigned_to,
      created_by,
      department_id,
      location_id,
      due_date_from,
      due_date_to,
      search,
      sort_by = 'created_at',
      sort_order = 'desc'
    } = filters;

    const offset = (page - 1) * limit;

    // Build where clause based on RBAC
    const visibilityScope = await RBACService.getTaskVisibilityScope(user);
    const where = { ...visibilityScope };

    // Apply filters
    if (status) where.status = status;
    if (priority) where.priority = priority;
    if (assigned_to) where.assigned_to_user_id = assigned_to;
    if (created_by) where.created_by_user_id = created_by;
    if (department_id) where.department_id = department_id;
    if (location_id) where.location_id = location_id;

    if (due_date_from || due_date_to) {
      where.due_date = {};
      if (due_date_from) where.due_date[Op.gte] = due_date_from;
      if (due_date_to) where.due_date[Op.lte] = due_date_to;
    }

    if (search) {
      where[Op.or] = [
        { title: { [Op.like]: `%${search}%` } },
        { description: { [Op.like]: `%${search}%` } }
      ];
    }

    // Query tasks
    const { count, rows: tasks } = await Task.findAndCountAll({
      where,
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
        { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] },
        { model: Company, as: 'company', attributes: ['id', 'name'] }
      ],
      order: [[sort_by, sort_order.toUpperCase()]],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    return {
      tasks,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: count,
        pages: Math.ceil(count / limit)
      }
    };
  }

  /**
   * Get task by ID
   */
  static async getTaskById(taskId, user) {
    const task = await Task.findByPk(taskId, {
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
        { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] },
        { model: Company, as: 'company', attributes: ['id', 'name'] }
      ]
    });

    if (!task) {
      throw new Error('Task not found');
    }

    // Check if user can view this task
    const canView = await RBACService.canViewTask(user, task);
    if (!canView) {
      throw new Error('Permission denied');
    }

    return task;
  }

  /**
   * Create new task
   */
  static async createTask(taskData, user) {
    // Set creator
    taskData.created_by_user_id = user.id;

    // Validate assigned user exists and is in same company
    const assignee = await User.findByPk(taskData.assigned_to);
    if (!assignee) {
      throw new Error('Assigned user not found');
    }

    if (user.role !== 'superadmin' && assignee.company_id !== user.company_id) {
      throw new Error('Cannot assign task to user from different company');
    }

    // Use creator's company_id; fall back to assignee's for superadmin with no company
    taskData.company_id = user.company_id || assignee.company_id;
    if (!taskData.company_id) {
      throw new Error('Cannot determine company for task');
    }

    // Create task
    const task = await Task.create({
      ...taskData,
      assigned_to_user_id: taskData.assigned_to
    });

    // Log activity
    await TaskActivity.create({
      task_id: task.id,
      user_id: user.id,
      action: 'created',
      details: `Task created and assigned to ${assignee.name}`
    });

    // Load associations
    await task.reload({
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
        { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] }
      ]
    });

    // Send assignment email (non-blocking)
    Mailer.sendTaskAssignment(
      assignee.email,
      assignee.name,
      task,
      user.name || 'Administrator'
    ).catch(err => logger.error('Assignment email failed:', err));

    return task;
  }

  /**
   * Update task
   */
  static async updateTask(taskId, updates, user) {
    const task = await Task.findByPk(taskId);

    if (!task) {
      throw new Error('Task not found');
    }

    // Check permissions
    const canEdit = await RBACService.canEditTask(user, task);
    if (!canEdit) {
      throw new Error('Permission denied');
    }

    // Track changes for activity log
    const changes = [];
    const oldValues = { ...task.dataValues };

    // Update task
    if (updates.assigned_to && updates.assigned_to !== task.assigned_to_user_id) {
      const newAssignee = await User.findByPk(updates.assigned_to);
      if (!newAssignee) {
        throw new Error('Assigned user not found');
      }
      changes.push(`Reassigned to ${newAssignee.name}`);
      updates.assigned_to_user_id = updates.assigned_to;
      delete updates.assigned_to;
    }

    if (updates.status && updates.status !== task.status) {
      changes.push(`Status changed from ${task.status} to ${updates.status}`);
    }

    if (updates.priority && updates.priority !== task.priority) {
      changes.push(`Priority changed from ${task.priority} to ${updates.priority}`);
    }

    const previousStatus = task.status;
    await task.update(updates);

    // Log activity
    if (changes.length > 0) {
      await TaskActivity.create({
        task_id: task.id,
        user_id: user.id,
        action: 'updated',
        details: changes.join(', ')
      });
    }

    // Reload with associations
    await task.reload({
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
        { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] }
      ]
    });

    // Send completion email to creator when task marked for review
    if (
      updates.status === 'complete_pending_review' &&
      previousStatus !== 'complete_pending_review' &&
      task.creator
    ) {
      Mailer.sendTaskCompletion(
        task.creator.email,
        task.creator.name,
        task,
        task.assignee?.name || user.name || 'Assignee'
      ).catch(err => logger.error('Completion email failed:', err));
    }

    return task;
  }

  /**
   * Delete task
   */
  static async deleteTask(taskId, user) {
    const task = await Task.findByPk(taskId);

    if (!task) {
      throw new Error('Task not found');
    }

    // Check permissions
    const canDelete = await RBACService.canDeleteTask(user, task);
    if (!canDelete) {
      throw new Error('Permission denied');
    }

    await task.destroy();

    logger.info(`Task ${taskId} deleted by user ${user.id}`);

    return { message: 'Task deleted successfully' };
  }

  /**
   * Get task activities
   */
  static async getTaskActivities(taskId, user) {
    const task = await Task.findByPk(taskId);

    if (!task) {
      throw new Error('Task not found');
    }

    // Check permissions
    const canView = await RBACService.canViewTask(user, task);
    if (!canView) {
      throw new Error('Permission denied');
    }

    const activities = await TaskActivity.findAll({
      where: { task_id: taskId },
      include: [
        { model: User, as: 'user', attributes: ['id', 'name', 'email'] }
      ],
      order: [['created_at', 'DESC']]
    });

    return activities;
  }

  /**
   * Submit task review
   */
  static async submitReview(taskId, reviewData, user) {
    const task = await Task.findByPk(taskId);

    if (!task) {
      throw new Error('Task not found');
    }

    // Check permissions
    const canReview = await RBACService.canReviewTask(user, task);
    if (!canReview) {
      throw new Error('Permission denied');
    }

    // Check if task is in reviewable state
    if (task.status !== 'complete_pending_review') {
      throw new Error('Task is not in a reviewable state');
    }

    // Create review
    const review = await TaskReview.create({
      task_id: taskId,
      reviewer_user_id: user.id,
      rating: reviewData.rating,
      comments: reviewData.comments,
      quality_score: reviewData.quality_score,
      timeliness_score: reviewData.timeliness_score
    });

    // Update task status to finalized
    await task.update({ status: 'finalized' });

    // Log activity
    await TaskActivity.create({
      task_id: taskId,
      user_id: user.id,
      action: 'reviewed',
      details: `Task reviewed with rating ${reviewData.rating}/5`
    });

    // Send review result email to assignee
    const assignee = await User.findByPk(task.assigned_to_user_id, { attributes: ['id', 'name', 'email'] });
    if (assignee) {
      Mailer.sendTaskReview(
        assignee.email,
        assignee.name,
        task,
        user.name || 'Reviewer',
        'approved',
        reviewData.comments
      ).catch(err => logger.error('Review email failed:', err));
    }

    return review;
  }

  /**
   * Bulk assign tasks to multiple users
   * Creates one copy of each task per user (or re-assigns if task_ids provided with single user logic)
   * Strategy: assign each task to each user → creates N*M assignments
   */
  static async bulkAssignTasks({ task_ids, user_ids }, requestingUser) {
    // Validate users exist and are in scope
    const users = await User.findAll({
      where: {
        id: { [require('sequelize').Op.in]: user_ids },
        is_active: true,
        ...(requestingUser.role !== 'superadmin' ? { company_id: requestingUser.company_id } : {})
      },
      attributes: ['id', 'name', 'company_id']
    });

    if (users.length === 0) throw new Error('No valid users found');

    // Fetch the source tasks
    const tasks = await Task.findAll({
      where: {
        id: { [require('sequelize').Op.in]: task_ids },
        ...(requestingUser.role !== 'superadmin' ? { company_id: requestingUser.company_id } : {})
      }
    });

    if (tasks.length === 0) throw new Error('No valid tasks found');

    const results = [];

    for (const task of tasks) {
      for (const user of users) {
        if (users.length === 1) {
          // Single user: re-assign the original task
          await task.update({ assigned_to_user_id: user.id });
          await TaskActivity.create({
            task_id: task.id,
            user_id: requestingUser.id,
            action: 'reassigned',
            details: `Bulk reassigned to ${user.name}`
          });
          results.push({ task_id: task.id, user_id: user.id, action: 'reassigned' });
        } else {
          // Multiple users: duplicate the task for each user
          const newTask = await Task.create({
            title: task.title,
            description: task.description,
            priority: task.priority,
            status: 'open',
            assigned_to_user_id: user.id,
            created_by_user_id: requestingUser.id,
            company_id: user.company_id,
            department_id: task.department_id,
            location_id: task.location_id,
            due_date: task.due_date,
            estimated_hours: task.estimated_hours,
            tags: task.tags
          });
          await TaskActivity.create({
            task_id: newTask.id,
            user_id: requestingUser.id,
            action: 'created',
            details: `Created via bulk assign from task #${task.id} for ${user.name}`
          });
          results.push({ task_id: newTask.id, user_id: user.id, action: 'created' });
        }
      }
    }

    return {
      assigned_count: results.length,
      task_count: tasks.length,
      user_count: users.length,
      results
    };
  }

  /**
   * Bulk create multiple tasks (one per row)
   */
  static async bulkCreateTasks(tasksData, user) {
    const results = [];
    const errors = [];

    for (const [index, taskData] of tasksData.entries()) {
      try {
        // Auto-assign department_id from assignee if not provided
        if (!taskData.department_id) {
          const assignee = await User.findByPk(taskData.assigned_to, { attributes: ['id', 'department_id'] });
          if (assignee && assignee.department_id) {
            taskData.department_id = assignee.department_id;
          } else if (user.department_id) {
            taskData.department_id = user.department_id;
          } else {
            throw new Error('Cannot determine department for task');
          }
        }
        const task = await TaskService.createTask(taskData, user);
        results.push(task);
      } catch (err) {
        logger.warn(`Bulk create row ${index} failed: ${err.message}`);
        errors.push({ index, error: err.message });
      }
    }

    return {
      created_count: results.length,
      failed_count: errors.length,
      tasks: results,
      errors
    };
  }

  /**
   * Get task statistics
   */
  static async getStatistics(filters, user) {
    const { start_date, end_date, department_id, location_id } = filters;

    // Build where clause
    const where = {};
    
    if (user.role !== 'superadmin') {
      where.company_id = user.company_id;
    }

    if (department_id) where.department_id = department_id;
    if (location_id) where.location_id = location_id;

    if (start_date || end_date) {
      where.created_at = {};
      if (start_date) where.created_at[Op.gte] = start_date;
      if (end_date) where.created_at[Op.lte] = end_date;
    }

    // Get counts by status
    const statusCounts = await Task.findAll({
      where,
      attributes: [
        'status',
        [Task.sequelize.fn('COUNT', Task.sequelize.col('id')), 'count']
      ],
      group: ['status']
    });

    // Get counts by priority
    const priorityCounts = await Task.findAll({
      where,
      attributes: [
        'priority',
        [Task.sequelize.fn('COUNT', Task.sequelize.col('id')), 'count']
      ],
      group: ['priority']
    });

    // Get average completion time
    const completedTasks = await Task.findAll({
      where: {
        ...where,
        status: 'finalized',
        completed_at: { [Op.ne]: null }
      },
      attributes: ['created_at', 'completed_at']
    });

    let avgCompletionTime = 0;
    if (completedTasks.length > 0) {
      const totalTime = completedTasks.reduce((sum, task) => {
        const diff = new Date(task.completed_at) - new Date(task.created_at);
        return sum + diff;
      }, 0);
      avgCompletionTime = totalTime / completedTasks.length / (1000 * 60 * 60 * 24); // Convert to days
    }

    return {
      status_counts: statusCounts.reduce((acc, item) => {
        acc[item.status] = parseInt(item.dataValues.count);
        return acc;
      }, {}),
      priority_counts: priorityCounts.reduce((acc, item) => {
        acc[item.priority] = parseInt(item.dataValues.count);
        return acc;
      }, {}),
      avg_completion_days: Math.round(avgCompletionTime * 10) / 10,
      total_tasks: statusCounts.reduce((sum, item) => sum + parseInt(item.dataValues.count), 0)
    };
  }
}

module.exports = TaskService;