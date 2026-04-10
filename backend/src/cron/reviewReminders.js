const cron = require('node-cron');
const { Task, User } = require('../models');
const { Op } = require('sequelize');
const mailer = require('../mail/mailer');
const logger = require('../utils/logger');

/**
 * Review Reminder Cron Job
 * Runs hourly to send reminders for tasks pending review for 24+ hours
 */
const reviewReminderJob = cron.schedule('0 * * * *', async () => {
  try {
    logger.info('Starting review reminder job');

    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Find tasks that:
    // 1. Are in complete_pending_review status
    // 2. Were completed more than 24 hours ago
    // 3. Haven't received a reminder in the last 24 hours (or never received one)
    const tasksNeedingReminder = await Task.findAll({
      where: {
        status: 'complete_pending_review',
        completed_at: {
          [Op.lte]: twentyFourHoursAgo
        },
        [Op.or]: [
          { last_review_reminder_at: null },
          {
            last_review_reminder_at: {
              [Op.lte]: twentyFourHoursAgo
            }
          }
        ]
      },
      include: [
        {
          association: 'creator',
          attributes: ['id', 'name', 'email']
        },
        {
          association: 'assignee',
          attributes: ['id', 'name']
        }
      ]
    });

    logger.info(`Found ${tasksNeedingReminder.length} tasks needing review reminders`);

    for (const task of tasksNeedingReminder) {
      try {
        // Send reminder to task creator
        if (task.creator && task.creator.email) {
          await mailer.sendReviewReminder(
            task.creator.email,
            task.creator.name,
            task
          );

          // Update last_review_reminder_at
          await task.update({
            last_review_reminder_at: now
          });

          logger.info(`Review reminder sent for task ${task.id} to ${task.creator.email}`);
        }

        // Also check if creator has a manager and send to them
        if (task.creator) {
          const creator = await User.findByPk(task.creator.id, {
            include: [{ association: 'manager', attributes: ['id', 'name', 'email'] }]
          });

          if (creator && creator.manager && creator.manager.email) {
            await mailer.sendReviewReminder(
              creator.manager.email,
              creator.manager.name,
              task
            );
            logger.info(`Review reminder sent for task ${task.id} to manager ${creator.manager.email}`);
          }
        }
      } catch (error) {
        logger.error(`Error sending reminder for task ${task.id}:`, error);
        // Continue with next task even if one fails
      }
    }

    logger.info('Review reminder job completed');
  } catch (error) {
    logger.error('Review reminder job error:', error);
  }
}, {
  scheduled: false // Don't start automatically, will be started in index.js
});

module.exports = reviewReminderJob;