const { Task, User, Department, Location, Company, TaskActivity, TaskReview, TaskAssignment, TaskApproval, TaskDependency, TaskAttachment } = require('../models');
const { Op } = require('sequelize');
const RBACService = require('./rbacService');
const logger = require('../utils/logger');
const Mailer = require('../mail/mailer');
const NotificationService = require('./notificationService');
const PerformanceService = require('./performanceService');

// Lightweight includes for list view — 5 simple JOINs, no many-to-many/nested
const TASK_LIST_INCLUDES = [
  { model: User, as: 'creator', attributes: ['id', 'name'] },
  { model: User, as: 'assignee', attributes: ['id', 'name'] },
  { model: Department, as: 'department', attributes: ['id', 'name'] },
  { model: Location, as: 'location', attributes: ['id', 'name'] },
  { model: Company, as: 'company', attributes: ['id', 'name'] }
];

// Full includes for single-task detail — collaborators + dependencies
const TASK_INCLUDES = [
  { model: User, as: 'creator', attributes: ['id', 'name', 'email'] },
  { model: User, as: 'assignee', attributes: ['id', 'name', 'email'] },
  { model: Department, as: 'department', attributes: ['id', 'name'] },
  { model: Location, as: 'location', attributes: ['id', 'name'] },
  { model: Company, as: 'company', attributes: ['id', 'name'] },
  {
    model: User, as: 'collaborators',
    attributes: ['id', 'name', 'email'],
    through: { attributes: [] }
  },
  {
    model: TaskDependency, as: 'dependencies',
    include: [{
      model: Task, as: 'dependsOn',
      attributes: ['id', 'title', 'status']
    }]
  }
];

/**
 * Apply cross-department privacy: viewer outside the task's dept sees the title (header)
 * but all sensitive details are masked — description, assignee, creator are hidden.
 */
function applyPrivacy(task, viewer) {
  const taskJson = task.toJSON ? task.toJSON() : { ...task };
  const viewerDeptId = viewer?.department_id;
  const viewerRole = viewer?.role;

  // Managers / dept heads / management / superadmin see everything
  if (['superadmin', 'management', 'department_head', 'manager'].includes(viewerRole)) {
    return taskJson;
  }

  // Same dept (or no dept info) → full view
  if (!viewerDeptId || !taskJson.department_id || taskJson.department_id === viewerDeptId) {
    return taskJson;
  }

  // Cross-dept: show title/status/priority/dates only, mask the rest
  taskJson.description = null;
  taskJson.assignee = null;
  taskJson.creator = null;
  taskJson.collaborators = [];
  taskJson._restricted = true;
  return taskJson;
}

/**
 * Build collaborator list respecting show_collaborators flag.
 */
function buildCollaboratorView(task, viewerUserId) {
  const t = task.toJSON ? task.toJSON() : { ...task };
  if (t.collaborators && !t.show_collaborators) {
    t.collaborators = t.collaborators.filter(c => c.id === viewerUserId);
  }
  return t;
}

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
    logger.info('[listTasks] user:', { id: user.id, role: user.role, company_id: user.company_id });
    logger.info('[listTasks] visibilityScope:', JSON.stringify(visibilityScope));
    const where = { ...visibilityScope };
    
    // Debug: check if tasks exist at all
    const totalCount = await Task.count();
    logger.info('[listTasks] total tasks in DB:', totalCount);
    
    // Debug: check tasks matching visibility scope
    const visibleCount = await Task.count({ where });
    logger.info('[listTasks] tasks matching visibility:', visibleCount);

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

    // Use lightweight includes for the list — no many-to-many/nested joins
    let count, tasks;
    try {
      ({ count, rows: tasks } = await Task.findAndCountAll({
        where,
        include: TASK_LIST_INCLUDES,
        order: [[sort_by, sort_order.toUpperCase()]],
        limit: parseInt(limit),
        offset: parseInt(offset),
      }));
      logger.info('[listTasks] query success:', { count, taskCount: tasks.length });
    } catch (err) {
      logger.error('[listTasks] query error:', err.message, err.stack);
      throw err;
    }

    // Apply privacy masking and collaborator visibility
    const processedTasks = tasks.map(t => {
      let taskData = buildCollaboratorView(t, user.id);
      taskData = applyPrivacy(taskData, user);
      return taskData;
    });

    return {
      tasks: processedTasks,
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
    const task = await Task.findByPk(taskId, { include: TASK_INCLUDES });

    if (!task) {
      throw new Error('Task not found');
    }

    const canView = await RBACService.canViewTask(user, task);
    if (!canView) {
      throw new Error('Permission denied');
    }

    let taskData = buildCollaboratorView(task, user.id);
    taskData = applyPrivacy(taskData, user);
    return taskData;
  }

  /**
   * Get workload summary for a specific user (for popup)
   */
  static async getUserWorkloadSummary(targetUserId, requestingUser) {
    const targetUser = await User.findByPk(targetUserId, {
      attributes: ['id', 'name', 'email'],
      include: [{ model: Department, as: 'department', attributes: ['id', 'name'] }]
    });
    if (!targetUser) throw new Error('User not found');

    const now = new Date();

    const [open, inProgress, overdue, upcoming] = await Promise.all([
      Task.count({ where: { assigned_to_user_id: targetUserId, status: 'open' } }),
      Task.count({ where: { assigned_to_user_id: targetUserId, status: 'in_progress' } }),
      Task.count({
        where: {
          assigned_to_user_id: targetUserId,
          status: { [Op.notIn]: ['finalized', 'cancelled'] },
          due_date: { [Op.lt]: now }
        }
      }),
      Task.findAll({
        where: {
          assigned_to_user_id: targetUserId,
          status: { [Op.notIn]: ['finalized', 'cancelled'] },
          due_date: { [Op.gte]: now }
        },
        order: [['due_date', 'ASC']],
        limit: 5,
        attributes: ['id', 'title', 'due_date', 'priority', 'status']
      })
    ]);

    return {
      user: {
        id: targetUser.id,
        name: targetUser.name,
        department: targetUser.department?.name || 'N/A'
      },
      open_tasks: open,
      in_progress_tasks: inProgress,
      overdue_tasks: overdue,
      upcoming_deadlines: upcoming.map(t => ({
        id: t.id,
        title: t.title,
        due_date: t.due_date,
        priority: t.priority
      }))
    };
  }

  /**
   * Create new task
   */
  static async createTask(taskData, user) {
    logger.info('[createTask] incoming data:', JSON.stringify({
      title: taskData.title,
      assigned_to: taskData.assigned_to,
      department_id: taskData.department_id,
      location_id: taskData.location_id,
      due_date: taskData.due_date,
      priority: taskData.priority,
      caller_id: user?.id,
      caller_role: user?.role,
      caller_company_id: user?.company_id
    }));

    taskData.created_by_user_id = user.id;

    // Support both single (assigned_to) and multi (assigned_to_ids) assignees
    const extraAssigneeIds = Array.isArray(taskData.assigned_to_ids)
      ? taskData.assigned_to_ids.filter(id => id !== taskData.assigned_to)
      : [];
    delete taskData.assigned_to_ids;

    // Remove fields that are not model columns
    delete taskData.tags;

    // Validate primary assignee
    const assignee = await User.findByPk(taskData.assigned_to);
    if (!assignee) throw new Error('Assigned user not found');

    logger.info(`[createTask] assignee found: id=${assignee.id} company_id=${assignee.company_id}`);

    if (user.role !== 'superadmin' && assignee.company_id !== user.company_id) {
      throw new Error('Cannot assign task to user from different company');
    }

    // Resolve company_id: prefer assignee's company (most reliable for superadmin)
    let companyId = assignee.company_id || user.company_id;

    // Last resort: look up from the department
    if (!companyId && taskData.department_id) {
      const dept = await Department.findByPk(taskData.department_id, { attributes: ['id', 'company_id'] });
      if (dept) companyId = dept.company_id;
    }

    // Last resort: look up from the location
    if (!companyId && taskData.location_id) {
      const loc = await Location.findByPk(taskData.location_id, { attributes: ['id', 'company_id'] });
      if (loc) companyId = loc.company_id;
    }

    // Fallback: if only one company exists, use it
    if (!companyId) {
      const companies = await Company.findAll({ attributes: ['id'], limit: 1 });
      if (companies.length === 1) companyId = companies[0].id;
    }

    if (!companyId) {
      logger.error('[createTask] Cannot determine company_id', { user_id: user.id, assignee_id: assignee.id });
      throw new Error('Cannot determine company for task. Please ensure users are assigned to a company.');
    }

    taskData.company_id = companyId;

    logger.info(`[createTask] resolved company_id=${companyId}`);

    // Handle depends_on
    const dependsOnId = taskData.depends_on_task_id || null;
    delete taskData.depends_on_task_id;

    // Build create payload — only include known model fields to avoid Sequelize warnings
    const createPayload = {
      title: taskData.title,
      description: taskData.description || null,
      priority: taskData.priority || 'normal',
      status: taskData.status || 'open',
      assigned_to_user_id: taskData.assigned_to,
      created_by_user_id: taskData.created_by_user_id,
      company_id: taskData.company_id,
      department_id: taskData.department_id,
      location_id: taskData.location_id,
      due_date: taskData.due_date || null,
      estimated_hours: taskData.estimated_hours || null,
      show_collaborators: taskData.show_collaborators !== false
    };

    logger.info('[createTask] createPayload built, calling Task.create...');

    // Create task
    const task = await Task.create(createPayload);

    // Create TaskAssignment entries — wrapped in try/catch in case table doesn't exist yet
    const allAssigneeIds = [assignee.id, ...extraAssigneeIds];
    const uniqueIds = [...new Set(allAssigneeIds)];
    try {
      await TaskAssignment.bulkCreate(
        uniqueIds.map(uid => ({ task_id: task.id, user_id: uid })),
        { ignoreDuplicates: true }
      );
    } catch (err) {
      logger.warn('TaskAssignment create skipped:', err.message);
    }

    // Create dependency if specified
    if (dependsOnId) {
      try {
        const depTask = await Task.findByPk(dependsOnId);
        if (depTask) {
          await TaskDependency.create({ task_id: task.id, depends_on_task_id: dependsOnId });
        }
      } catch (err) {
        logger.warn('TaskDependency create skipped:', err.message);
      }
    }

    // Activity log
    const assigneeNames = assignee.name +
      (extraAssigneeIds.length > 0 ? ` + ${extraAssigneeIds.length} others` : '');
    await TaskActivity.create({
      task_id: task.id,
      actor_user_id: user.id,
      action: 'created',
      note: `Task created and assigned to ${assigneeNames}`
    });

    // Reload with full includes; fall back to basic reload if new tables don't exist yet
    try {
      await task.reload({ include: TASK_INCLUDES });
    } catch (err) {
      logger.warn('Full task reload failed, using basic reload:', err.message);
      await task.reload();
    }

    // Send emails and notifications to all assignees (non-blocking)
    for (const uid of uniqueIds) {
      const u = await User.findByPk(uid, { attributes: ['id', 'name', 'email'] });
      if (u) {
        Mailer.sendTaskAssignment(u.email, u.name, task, user.name || 'Administrator')
          .catch(err => logger.error('Assignment email failed:', err));
        
        // Send task assigned notification (if not the creator)
        if (uid !== user.id) {
          NotificationService.notifyTaskAssigned({ ...task.toJSON(), assigned_to_user_id: uid })
            .catch(err => logger.error('Failed to create assignment notification:', err));
        }
      }
    }

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
    let oldAssigneeId = task.assigned_to_user_id;
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
        actor_user_id: user.id,
        action: 'updated',
        note: changes.join(', ')
      });
    }

    await task.reload({ include: TASK_INCLUDES });

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

    // Send status change notification to assignee
    if (updates.status && previousStatus !== updates.status && task.assigned_to_user_id) {
      NotificationService.notifyTaskStatusChanged(task, previousStatus)
        .catch(err => logger.error('Failed to create status change notification:', err));
    }

    // Send task assigned notification if reassigned
    if (updates.assigned_to_user_id && oldAssigneeId !== updates.assigned_to_user_id) {
      NotificationService.notifyTaskAssigned(task)
        .catch(err => logger.error('Failed to create reassignment notification:', err));
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
   * Complete task - mark as complete_pending_review
   */
  static async completeTask(taskId, user) {
    const task = await Task.findByPk(taskId, { include: TASK_INCLUDES });

    if (!task) {
      throw new Error('Task not found');
    }

    // Only the assigned user can complete the task
    if (task.assigned_to_user_id !== user.id) {
      throw new Error('Only the assigned user can mark a task as complete');
    }

    // Task must be in open or in_progress status to be completed
    if (!['open', 'in_progress', 'reopened'].includes(task.status)) {
      throw new Error(`Task with status "${task.status}" cannot be marked as complete`);
    }

    // Update task status and completion timestamp
    const updateData = {
      status: 'complete_pending_review',
      completed_at: new Date()
    };
    // Track first completion for cycle-time metrics
    if (!task.first_completed_at) {
      updateData.first_completed_at = new Date();
    }
    await task.update(updateData);

    // Log activity
    await TaskActivity.create({
      task_id: task.id,
      actor_user_id: user.id,
      action: 'completed',
      note: 'Task marked as complete and pending review'
    });

    // Reload to get fresh data
    await task.reload({ include: TASK_INCLUDES });

    // Send completion notification email to task creator
    if (task.creator) {
      Mailer.sendTaskCompletion(
        task.creator.email,
        task.creator.name,
        task,
        user.name || 'Assignee'
      ).catch(err => logger.error('Completion email failed:', err));
    }

    // Create task completion notification for task creator
    if (task.created_by_user_id && task.created_by_user_id !== user.id) {
      NotificationService.notifyTaskCompleted(task).catch(err => 
        logger.error('Failed to create completion notification:', err)
      );
    }

    logger.info(`Task ${taskId} marked as complete by user ${user.id}`);

    return task;
  }

  /**
   * Reopen a completed/finalized task — only the task creator (assigner) can do this.
   * Requires a mandatory comment explaining why the task is being reopened.
   */
  static async reopenTask(taskId, comment, user) {
    const { sequelize } = require('../models');
    const transaction = await sequelize.transaction();

    try {
      const task = await Task.findByPk(taskId, { include: TASK_INCLUDES, transaction });

      if (!task) {
        throw new Error('Task not found');
      }

      // Only the task creator (assigner) can reopen
      if (task.created_by_user_id !== user.id) {
        throw new Error('Only the task creator can reopen a task');
      }

      // Task must be in a completed or finalized state to be reopened
      if (!['complete_pending_review', 'finalized'].includes(task.status)) {
        throw new Error(`Task with status "${task.status}" cannot be reopened. Only completed or finalized tasks can be reopened.`);
      }

      const previousStatus = task.status;

      // Update task status and audit fields
      await task.update({
        status: 'in_progress',
        reopen_count: (task.reopen_count || 0) + 1,
        last_reopened_at: new Date(),
        approval_status: null,
        completed_at: null
      }, { transaction });

      // Log activity with mandatory comment
      await TaskActivity.create({
        task_id: task.id,
        actor_user_id: user.id,
        action: 'reopened',
        note: comment
      }, { transaction });

      await transaction.commit();

      // Reload to get fresh data
      await task.reload({ include: TASK_INCLUDES });

      // Send notification to assignee
      if (task.assigned_to_user_id && task.assigned_to_user_id !== user.id) {
        NotificationService.createNotification(
          task.assigned_to_user_id,
          'task_reopened',
          {
            title: `Task "${task.title}" has been reopened`,
            description: `${user.name || 'Manager'} reopened this task: ${comment}`,
            taskId: task.id,
            metadata: {
              previous_status: previousStatus,
              reopen_comment: comment,
              reopen_count: task.reopen_count,
              reopened_by: user.name || user.email
            }
          }
        ).catch(err => logger.error('Failed to create reopen notification:', err));
      }

      // Emit socket event for real-time update
      if (global.io && task.company_id) {
        global.io.to(`company:${task.company_id}`).emit('task:reopened', {
          taskId: task.id,
          action: 'reopened',
          previousStatus,
          timestamp: new Date()
        });
      }

      logger.info(`Task ${taskId} reopened by user ${user.id} (reopen #${task.reopen_count}). Reason: ${comment}`);

      return task;
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
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
        { model: User, as: 'actor', attributes: ['id', 'name', 'email'] }
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
      actor_user_id: user.id,
      action: 'approved',
      note: `Task reviewed with rating ${reviewData.rating}/5`
    });

    // Update performance metrics for the assignee (async, non-blocking)
    if (task.assigned_to_user_id) {
      // Get current month/year
      const now = new Date();
      const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const currentMonthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);
      
      // Update user metrics for current month
      PerformanceService.calculateUserMetrics(
        task.assigned_to_user_id,
        currentMonthStart,
        currentMonthEnd
      ).catch(err => logger.error('Performance metrics update failed:', err));

      // Also update employee performance
      if (task.department_id) {
        const performanceData = {
          average_quality_score: reviewData.quality_score || 0,
          overall_rating: reviewData.rating || 0
        };
        PerformanceService.updateEmployeePerformance(
          task.assigned_to_user_id,
          task.department_id,
          performanceData
        ).catch(err => logger.error('Employee performance update failed:', err));
      }
    }

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
            actor_user_id: requestingUser.id,
            action: 'assigned',
            note: `Bulk reassigned to ${user.name}`
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
            actor_user_id: requestingUser.id,
            action: 'created',
            note: `Created via bulk assign from task #${task.id} for ${user.name}`
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
            // Try to determine from location
            if (taskData.location_id) {
              const loc = await Location.findByPk(taskData.location_id, { attributes: ['id', 'company_id'] });
              if (!loc) throw new Error('Cannot determine department for task');
            } else {
              throw new Error('Cannot determine department for task');
            }
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

    // Build where clause using RBAC visibility scope
    const visibilityScope = await RBACService.getTaskVisibilityScope(user);
    const where = { ...visibilityScope };

    // Management-level can further filter by dept/location
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

    // Get overdue task count
    const overdueCount = await Task.count({
      where: {
        ...where,
        status: { [Op.notIn]: ['finalized'] },
        due_date: { [Op.lt]: new Date() }
      }
    });

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
      total_tasks: statusCounts.reduce((sum, item) => sum + parseInt(item.dataValues.count), 0),
      overdue_tasks: overdueCount
    };
  }
}

module.exports = TaskService;