'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      // Add task_reopened to notifications type enum
      await queryInterface.changeColumn('notifications', 'type', {
        type: Sequelize.ENUM(
          'task_assigned',
          'task_completed',
          'task_commented',
          'task_deadline_approaching',
          'task_status_changed',
          'task_review_pending',
          'task_review_approved',
          'task_review_rejected',
          'task_approval_pending',
          'task_approval_approved',
          'task_approval_rejected',
          'task_reopened'
        ),
        allowNull: false
      }, { transaction });
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.changeColumn('notifications', 'type', {
        type: Sequelize.ENUM(
          'task_assigned',
          'task_completed',
          'task_commented',
          'task_deadline_approaching',
          'task_status_changed',
          'task_review_pending',
          'task_review_approved',
          'task_review_rejected',
          'task_approval_pending',
          'task_approval_approved',
          'task_approval_rejected'
        ),
        allowNull: false
      }, { transaction });
    });
  }
};
