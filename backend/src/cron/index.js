const reviewReminderJob = require('./reviewReminders');
const escalationJob = require('./escalation');
const logger = require('../utils/logger');

/**
 * Initialize and start all cron jobs
 */
const startCronJobs = () => {
  logger.info('Starting cron jobs...');

  reviewReminderJob.start();
  logger.info('Review reminder job started (runs hourly at :00)');

  escalationJob.start();
  logger.info('Auto-escalation job started (runs hourly at :30)');
};

/**
 * Stop all cron jobs
 */
const stopCronJobs = () => {
  logger.info('Stopping cron jobs...');
  reviewReminderJob.stop();
  escalationJob.stop();
};

module.exports = {
  startCronJobs,
  stopCronJobs
};