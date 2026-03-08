const bcrypt = require('bcrypt');
const { User, Task, Department, Location, Company, TaskReview, UserCompany, UserLocation } = require('../models');
const { Op } = require('sequelize');
const RBACService = require('./rbacService');
const logger = require('../utils/logger');

class UserService {
  /**
   * Get user workload
   */
  static async getUserWorkload(userId, requestingUser) {
    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error('User not found');
    }

    // Check permissions
    const accessibleUserIds = await RBACService.getAccessibleUserIds(requestingUser);
    if (!accessibleUserIds.includes(userId)) {
      throw new Error('Permission denied');
    }

    // Get task counts by status
    const taskCounts = await Task.findAll({
      where: {
        assigned_to_user_id: userId,
        status: { [Op.ne]: 'finalized' }
      },
      attributes: [
        'status',
        [Task.sequelize.fn('COUNT', Task.sequelize.col('id')), 'count']
      ],
      group: ['status']
    });

    // Get overdue tasks
    const overdueTasks = await Task.count({
      where: {
        assigned_to_user_id: userId,
        status: { [Op.notIn]: ['finalized', 'cancelled'] },
        due_date: { [Op.lt]: new Date() }
      }
    });

    // Get upcoming tasks (due in next 7 days)
    const upcomingTasks = await Task.count({
      where: {
        assigned_to_user_id: userId,
        status: { [Op.notIn]: ['finalized', 'cancelled'] },
        due_date: {
          [Op.gte]: new Date(),
          [Op.lte]: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        }
      }
    });

    // Calculate total estimated hours
    const totalEstimatedHours = await Task.sum('estimated_hours', {
      where: {
        assigned_to_user_id: userId,
        status: { [Op.notIn]: ['finalized', 'cancelled'] }
      }
    });

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email
      },
      task_counts: taskCounts.reduce((acc, item) => {
        acc[item.status] = parseInt(item.dataValues.count);
        return acc;
      }, {}),
      overdue_tasks: overdueTasks,
      upcoming_tasks: upcomingTasks,
      total_estimated_hours: totalEstimatedHours || 0
    };
  }

  /**
   * Get user performance metrics
   */
  static async getUserPerformance(userId, requestingUser) {
    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error('User not found');
    }

    // Check permissions
    const accessibleUserIds = await RBACService.getAccessibleUserIds(requestingUser);
    if (!accessibleUserIds.includes(userId)) {
      throw new Error('Permission denied');
    }

    // Get completed tasks count
    const completedTasks = await Task.count({
      where: {
        assigned_to_user_id: userId,
        status: 'finalized'
      }
    });

    // Get average rating from reviews
    const reviews = await TaskReview.findAll({
      include: [{
        model: Task,
        as: 'task',
        where: { assigned_to_user_id: userId },
        attributes: []
      }],
      attributes: [
        [Task.sequelize.fn('AVG', Task.sequelize.col('rating')), 'avg_rating'],
        [Task.sequelize.fn('AVG', Task.sequelize.col('quality_score')), 'avg_quality'],
        [Task.sequelize.fn('AVG', Task.sequelize.col('timeliness_score')), 'avg_timeliness'],
        [Task.sequelize.fn('COUNT', Task.sequelize.col('TaskReview.id')), 'review_count']
      ],
      raw: true
    });

    // Get on-time completion rate
    const finalizedTasks = await Task.findAll({
      where: {
        assigned_to_user_id: userId,
        status: 'finalized',
        completed_at: { [Op.ne]: null }
      },
      attributes: ['due_date', 'completed_at']
    });

    let onTimeCount = 0;
    finalizedTasks.forEach(task => {
      if (task.completed_at && task.due_date) {
        const completedDate = new Date(task.completed_at);
        const dueDate = new Date(task.due_date);
        if (completedDate <= dueDate) {
          onTimeCount++;
        }
      }
    });

    const onTimeRate = finalizedTasks.length > 0
      ? (onTimeCount / finalizedTasks.length) * 100
      : 0;

    // Get average completion time
    let avgCompletionDays = 0;
    if (finalizedTasks.length > 0) {
      const totalDays = finalizedTasks.reduce((sum, task) => {
        const created = new Date(task.created_at);
        const completed = new Date(task.completed_at);
        const days = (completed - created) / (1000 * 60 * 60 * 24);
        return sum + days;
      }, 0);
      avgCompletionDays = totalDays / finalizedTasks.length;
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email
      },
      completed_tasks: completedTasks,
      avg_rating: reviews[0]?.avg_rating ? parseFloat(reviews[0].avg_rating).toFixed(2) : null,
      avg_quality_score: reviews[0]?.avg_quality ? parseFloat(reviews[0].avg_quality).toFixed(2) : null,
      avg_timeliness_score: reviews[0]?.avg_timeliness ? parseFloat(reviews[0].avg_timeliness).toFixed(2) : null,
      review_count: reviews[0]?.review_count || 0,
      on_time_completion_rate: Math.round(onTimeRate * 10) / 10,
      avg_completion_days: Math.round(avgCompletionDays * 10) / 10
    };
  }

  /**
   * List users with filters
   */
  static async listUsers(filters, requestingUser) {
    const {
      page = 1,
      limit = 20,
      role,
      department_id,
      location_id,
      is_active,
      search
    } = filters;

    const offset = (page - 1) * limit;

    // Build where clause
    const where = {};

    // Apply company scope
    if (requestingUser.role !== 'superadmin') {
      where.company_id = requestingUser.company_id;
    }

    if (role) where.role = role;
    if (department_id) where.department_id = department_id;
    if (location_id) where.location_id = location_id;
    if (is_active !== undefined) where.is_active = is_active;

    if (search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } }
      ];
    }

    const { count, rows: users } = await User.findAndCountAll({
      where,
      attributes: { exclude: ['password_hash'] },
      include: [
        { model: Company, as: 'company', attributes: ['id', 'name'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] },
        { model: User, as: 'manager', attributes: ['id', 'name'] },
        { model: User, as: 'department_head', attributes: ['id', 'name'] }
      ],
      order: [['name', 'ASC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    return {
      users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: count,
        pages: Math.ceil(count / limit)
      }
    };
  }

  /**
   * Get user by ID
   */
  static async getUser(userId, requestingUser) {
    const user = await User.findByPk(userId, {
      attributes: { exclude: ['password_hash'] },
      include: [
        { model: Company, as: 'company', attributes: ['id', 'name'] },
        { model: Department, as: 'department', attributes: ['id', 'name'] },
        { model: Location, as: 'location', attributes: ['id', 'name'] },
        { model: User, as: 'manager', attributes: ['id', 'name', 'email'] },
        { model: User, as: 'department_head', attributes: ['id', 'name', 'email'] }
      ]
    });

    if (!user) {
      throw new Error('User not found');
    }

    // Check permissions
    if (requestingUser.role !== 'superadmin' && user.company_id !== requestingUser.company_id) {
      throw new Error('Permission denied');
    }

    return user;
  }

  /**
   * Generate a unique username from full name
   */
  static async generateUniqueUsername(fullName) {
    const parts = String(fullName || '').toLowerCase()
      .replace(/[^a-z0-9\s]/g, '').trim().split(/\s+/).filter(Boolean);
    const base = parts.length >= 2
      ? `${parts[0]}.${parts[parts.length - 1]}`
      : (parts[0] || 'user');
    let candidate = base;
    let i = 2;
    while (await User.findOne({ where: { username: candidate } })) {
      candidate = `${base}${i++}`;
    }
    return candidate;
  }

  /**
   * Create new user
   */
  static async createUser(userData, requestingUser) {
    // Set company
    if (requestingUser.role !== 'superadmin') {
      userData.company_id = requestingUser.company_id;
    }

    // Check if email already exists
    const existingUser = await User.findOne({
      where: { email: userData.email.toLowerCase() }
    });

    if (existingUser) {
      throw new Error('Email already exists');
    }

    // Build name from first_name + last_name if name not provided
    if (!userData.name && (userData.first_name || userData.last_name)) {
      userData.name = `${userData.first_name || ''} ${userData.last_name || ''}`.trim();
    }
    delete userData.first_name;
    delete userData.last_name;

    // Auto-generate username if not provided
    if (!userData.username) {
      userData.username = await UserService.generateUniqueUsername(userData.name);
    }

    // Hash password
    const passwordHash = await bcrypt.hash(userData.password, 10);

    // Create user
    const user = await User.create({
      ...userData,
      email: userData.email.toLowerCase(),
      password_hash: passwordHash,
      force_password_change: true
    });

    logger.info(`User created: ${user.email} by ${requestingUser.email}`);

    // Handle multi-company assignments
    if (Array.isArray(userData.company_ids) && userData.company_ids.length > 0) {
      await UserCompany.destroy({ where: { user_id: user.id } });
      for (let i = 0; i < userData.company_ids.length; i++) {
        await UserCompany.create({ user_id: user.id, company_id: userData.company_ids[i], is_primary: i === 0 });
      }
    }
    // Handle multi-location assignments
    if (Array.isArray(userData.location_ids) && userData.location_ids.length > 0) {
      await UserLocation.destroy({ where: { user_id: user.id } });
      for (let i = 0; i < userData.location_ids.length; i++) {
        await UserLocation.create({ user_id: user.id, location_id: userData.location_ids[i], is_primary: i === 0 });
      }
    }

    // Remove password from response
    const userResponse = user.toJSON();
    delete userResponse.password_hash;

    return userResponse;
  }

  /**
   * Update user
   */
  static async updateUser(userId, updates, requestingUser) {
    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error('User not found');
    }

    // Check permissions
    if (requestingUser.role !== 'superadmin' && user.company_id !== requestingUser.company_id) {
      throw new Error('Permission denied');
    }

    // Don't allow changing company unless superadmin
    if (updates.company_id && requestingUser.role !== 'superadmin') {
      delete updates.company_id;
    }

    // If email is being updated, check for duplicates
    if (updates.email && updates.email !== user.email) {
      const existingUser = await User.findOne({
        where: {
          email: updates.email.toLowerCase(),
          id: { [Op.ne]: userId }
        }
      });

      if (existingUser) {
        throw new Error('Email already exists');
      }

      updates.email = updates.email.toLowerCase();
    }

    // If password is being updated, hash it
    if (updates.password) {
      updates.password_hash = await bcrypt.hash(updates.password, 10);
      delete updates.password;
    }

    await user.update(updates);

    logger.info(`User updated: ${user.email} by ${requestingUser.email}`);

    // Handle multi-company assignments
    if (Array.isArray(updates.company_ids) && updates.company_ids.length > 0) {
      await UserCompany.destroy({ where: { user_id: user.id } });
      for (let i = 0; i < updates.company_ids.length; i++) {
        await UserCompany.create({ user_id: user.id, company_id: updates.company_ids[i], is_primary: i === 0 });
      }
    }
    // Handle multi-location assignments
    if (Array.isArray(updates.location_ids) && updates.location_ids.length > 0) {
      await UserLocation.destroy({ where: { user_id: user.id } });
      for (let i = 0; i < updates.location_ids.length; i++) {
        await UserLocation.create({ user_id: user.id, location_id: updates.location_ids[i], is_primary: i === 0 });
      }
    }

    // Remove password from response
    const userResponse = user.toJSON();
    delete userResponse.password_hash;

    return userResponse;
  }

  /**
   * Delete user
   */
  static async deleteUser(userId, requestingUser) {
    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error('User not found');
    }

    // Check if user has any tasks
    const taskCount = await Task.count({
      where: {
        [Op.or]: [
          { created_by_user_id: userId },
          { assigned_to_user_id: userId }
        ]
      }
    });

    if (taskCount > 0) {
      throw new Error('Cannot delete user with associated tasks. Please reassign tasks first.');
    }

    await user.destroy();

    logger.info(`User deleted: ${user.email} by ${requestingUser.email}`);

    return { message: 'User deleted successfully' };
  }
}

module.exports = UserService;