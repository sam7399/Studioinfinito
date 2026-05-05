const { Task, TaskMetrics, DepartmentMetrics, EmployeePerformance, User, Department, TaskReview } = require('../models');
const { Op } = require('sequelize');
const logger = require('../utils/logger');

class PerformanceService {
  /**
   * Calculate user metrics for a specific period
   */
  static async calculateUserMetrics(userId, startDate, endDate) {
    try {
      const user = await User.findByPk(userId);
      if (!user) throw new Error('User not found');

      // Get all tasks completed by user in the period
      const completedTasks = await Task.findAll({
        where: {
          assigned_to_user_id: userId,
          status: { [Op.in]: ['finalized', 'complete_pending_review'] },
          updated_at: { [Op.between]: [startDate, endDate] }
        },
        include: [
          { model: TaskReview, as: 'reviews' },
          { model: Task, as: 'dependencies', through: 'task_dependencies' }
        ]
      });

      // Calculate metrics
      let tasksOnTime = 0;
      let tasksLate = 0;
      let totalCompletionDays = 0;
      let totalQualityScore = 0;
      let rejectionCount = 0;

      completedTasks.forEach(task => {
        const dueDateObj = new Date(task.due_date);
        const completedDateObj = new Date(task.updated_at);

        // Calculate on-time vs late
        if (completedDateObj <= dueDateObj) {
          tasksOnTime++;
        } else {
          tasksLate++;
        }

        // Calculate completion days
        const daysDiff = Math.ceil((completedDateObj - new Date(task.created_at)) / (1000 * 60 * 60 * 24));
        totalCompletionDays += daysDiff;

        // Get quality score from task reviews
        if (task.reviews && task.reviews.length > 0) {
          const avgRating = task.reviews.reduce((sum, review) => sum + (review.quality_score || 0), 0) / task.reviews.length;
          totalQualityScore += avgRating;
        }

        // Count rejections
        if (task.approval_status === 'rejected') {
          rejectionCount++;
        }
      });

      const taskCount = completedTasks.length || 1; // Prevent division by zero

      const metrics = {
        user_id: userId,
        tasks_completed: completedTasks.length,
        tasks_on_time: tasksOnTime,
        tasks_late: tasksLate,
        tasks_pending_review: 0,
        average_completion_days: parseFloat((totalCompletionDays / taskCount).toFixed(2)),
        average_quality_score: totalQualityScore > 0 ? parseFloat((totalQualityScore / taskCount).toFixed(2)) : 0,
        rejection_count: rejectionCount,
        period_start: startDate,
        period_end: endDate
      };

      // Update or create metrics record
      const [metricsRecord] = await TaskMetrics.findOrCreate({
        where: {
          user_id: userId,
          period_start: startDate,
          period_end: endDate
        },
        defaults: metrics
      });

      if (metricsRecord) {
        await metricsRecord.update(metrics);
      }

      return metricsRecord;
    } catch (error) {
      logger.error('Calculate user metrics error:', error);
      throw error;
    }
  }

  /**
   * Calculate department metrics for a specific month/year
   */
  static async calculateDepartmentMetrics(departmentId, month, year) {
    try {
      const department = await Department.findByPk(departmentId);
      if (!department) throw new Error('Department not found');

      // Get date range for the month
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0);

      // Get all tasks for the department completed in this period
      const allTasks = await Task.findAll({
        where: {
          department_id: departmentId,
          updated_at: { [Op.between]: [startDate, endDate] }
        },
        include: [
          { model: User, as: 'assignee', attributes: ['id', 'name'] },
          { model: TaskReview, as: 'reviews' }
        ]
      });

      const completedTasks = allTasks.filter(t => ['finalized', 'complete_pending_review'].includes(t.status));

      // Calculate metrics
      let onTimeTasks = 0;
      let lateTasks = 0;
      let totalCompletionDays = 0;
      let totalQualityScore = 0;

      completedTasks.forEach(task => {
        const dueDateObj = new Date(task.due_date);
        const completedDateObj = new Date(task.updated_at);

        if (completedDateObj <= dueDateObj) {
          onTimeTasks++;
        } else {
          lateTasks++;
        }

        const daysDiff = Math.ceil((completedDateObj - new Date(task.created_at)) / (1000 * 60 * 60 * 24));
        totalCompletionDays += daysDiff;

        if (task.reviews && task.reviews.length > 0) {
          const avgRating = task.reviews.reduce((sum, review) => sum + (review.quality_score || 0), 0) / task.reviews.length;
          totalQualityScore += avgRating;
        }
      });

      const completedCount = completedTasks.length || 1;
      const totalCount = allTasks.length || 1;

      // Get team size (active users in department)
      const teamSize = await User.count({
        where: {
          department_id: departmentId,
          is_active: true
        }
      });

      const metrics = {
        department_id: departmentId,
        total_tasks: allTasks.length,
        completed_tasks: completedTasks.length,
        on_time_tasks: onTimeTasks,
        late_tasks: lateTasks,
        on_time_percentage: parseFloat(((onTimeTasks / completedCount) * 100).toFixed(2)),
        completion_percentage: parseFloat(((completedCount / totalCount) * 100).toFixed(2)),
        average_time_to_complete: parseFloat((totalCompletionDays / completedCount).toFixed(2)),
        average_quality_score: totalQualityScore > 0 ? parseFloat((totalQualityScore / completedCount).toFixed(2)) : 0,
        team_size: teamSize,
        month: month,
        year: year
      };

      // Update or create metrics record
      const [metricsRecord] = await DepartmentMetrics.findOrCreate({
        where: {
          department_id: departmentId,
          month: month,
          year: year
        },
        defaults: metrics
      });

      if (metricsRecord) {
        await metricsRecord.update(metrics);
      }

      return metricsRecord;
    } catch (error) {
      logger.error('Calculate department metrics error:', error);
      throw error;
    }
  }

  /**
   * Get detailed performance report for a user
   */
  static async getPerformanceReport(userId) {
    try {
      const user = await User.findByPk(userId, {
        include: [
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ]
      });

      if (!user) throw new Error('User not found');

      // Get latest 3 months metrics
      const metrics = await TaskMetrics.findAll({
        where: { user_id: userId },
        order: [['period_start', 'DESC']],
        limit: 3
      });

      // Get employee performance record
      const performance = await EmployeePerformance.findOne({
        where: { user_id: userId },
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'emp_code'] }
        ]
      });

      // Get recent tasks
      const recentTasks = await Task.findAll({
        where: { assigned_to_user_id: userId },
        order: [['updated_at', 'DESC']],
        limit: 10,
        attributes: ['id', 'title', 'status', 'priority', 'due_date', 'created_at', 'updated_at']
      });

      return {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          emp_code: user.emp_code,
          department: user.department
        },
        performance: performance || {},
        metrics: metrics,
        recent_tasks: recentTasks,
        generated_at: new Date()
      };
    } catch (error) {
      logger.error('Get performance report error:', error);
      throw error;
    }
  }

  /**
   * Get top performers in a department
   */
  static async getTopPerformers(departmentId, limit = 10) {
    try {
      const topPerformers = await EmployeePerformance.findAll({
        where: { department_id: departmentId },
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'emp_code', 'email'] },
          { model: Department, as: 'department', attributes: ['id', 'name'] }
        ],
        order: [['overall_rating', 'DESC'], ['task_completion_rate', 'DESC']],
        limit: limit
      });

      return topPerformers;
    } catch (error) {
      logger.error('Get top performers error:', error);
      throw error;
    }
  }

  /**
   * Generate company-wide HR report for a month/year
   */
  static async generateHRReport(month, year) {
    try {
      // Get all departments
      const departments = await Department.findAll({
        attributes: ['id', 'name']
      });

      const reportData = {
        month: month,
        year: year,
        generated_at: new Date(),
        company_summary: {},
        departments: []
      };

      let totalTasks = 0;
      let totalCompleted = 0;
      let totalOnTime = 0;
      let totalTeamSize = 0;

      // Calculate metrics for each department
      for (const dept of departments) {
        const metrics = await this.calculateDepartmentMetrics(dept.id, month, year);
        reportData.departments.push({
          id: dept.id,
          name: dept.name,
          ...metrics.toJSON()
        });

        totalTasks += metrics.total_tasks;
        totalCompleted += metrics.completed_tasks;
        totalOnTime += metrics.on_time_tasks;
        totalTeamSize += metrics.team_size;
      }

      // Company summary
      reportData.company_summary = {
        total_tasks: totalTasks,
        completed_tasks: totalCompleted,
        on_time_tasks: totalOnTime,
        completion_rate: totalTasks > 0 ? parseFloat(((totalCompleted / totalTasks) * 100).toFixed(2)) : 0,
        on_time_rate: totalCompleted > 0 ? parseFloat(((totalOnTime / totalCompleted) * 100).toFixed(2)) : 0,
        total_employees: totalTeamSize,
        department_count: departments.length
      };

      return reportData;
    } catch (error) {
      logger.error('Generate HR report error:', error);
      throw error;
    }
  }

  /**
   * Get performance trends over time for a user
   */
  static async getPerformanceTrends(userId, months = 6) {
    try {
      const trends = await TaskMetrics.findAll({
        where: { user_id: userId },
        order: [['period_start', 'DESC']],
        limit: months
      });

      return trends.reverse(); // Return in chronological order
    } catch (error) {
      logger.error('Get performance trends error:', error);
      throw error;
    }
  }

  /**
   * Update employee performance record
   */
  static async updateEmployeePerformance(userId, departmentId, performanceData) {
    try {
      const [performance] = await EmployeePerformance.findOrCreate({
        where: { user_id: userId, department_id: departmentId },
        defaults: {
          user_id: userId,
          department_id: departmentId,
          ...performanceData
        }
      });

      if (performance) {
        await performance.update({
          ...performanceData,
          last_evaluated: new Date()
        });
      }

      return performance;
    } catch (error) {
      logger.error('Update employee performance error:', error);
      throw error;
    }
  }

  /**
   * Calculate performance for all users in a department
   */
  static async calculateDepartmentPerformances(departmentId, month, year) {
    try {
      const users = await User.findAll({
        where: { department_id: departmentId, is_active: true }
      });

      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0);

      const results = [];

      for (const user of users) {
        const metrics = await this.calculateUserMetrics(user.id, startDate, endDate);
        
        // Update employee performance
        const performanceData = {
          task_completion_rate: metrics.tasks_completed > 0 ? 100 : 0,
          on_time_completion_rate: metrics.tasks_completed > 0 
            ? parseFloat(((metrics.tasks_on_time / metrics.tasks_completed) * 100).toFixed(2))
            : 0,
          average_quality_score: metrics.average_quality_score,
          overall_rating: parseFloat((
            (metrics.average_quality_score * 0.6 + 
             (metrics.tasks_completed > 0 ? ((metrics.tasks_on_time / metrics.tasks_completed) * 5) : 0) * 0.4)
          ).toFixed(2))
        };

        await this.updateEmployeePerformance(user.id, departmentId, performanceData);
        results.push({
          user_id: user.id,
          user_name: user.name,
          ...performanceData
        });
      }

      return results;
    } catch (error) {
      logger.error('Calculate department performances error:', error);
      throw error;
    }
  }
}

module.exports = PerformanceService;
