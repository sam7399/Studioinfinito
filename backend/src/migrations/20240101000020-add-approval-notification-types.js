'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add new notification types for task approval workflow
    // This migration adds: task_approval_pending, task_approval_approved, task_approval_rejected

    await queryInterface.sequelize.transaction(async (transaction) => {
      // Get the current enum type
      const enumType = 'ENUM(\'task_assigned\', \'task_completed\', \'task_commented\', \'task_deadline_approaching\', \'task_status_changed\', \'task_review_pending\', \'task_review_approved\', \'task_review_rejected\', \'task_approval_pending\', \'task_approval_approved\', \'task_approval_rejected\', \'system\')';

      // Change the column type to add new values
      await queryInterface.changeColumn(
        'notifications',
        'type',
        {
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
            'system'
          ),
          allowNull: false,
          defaultValue: 'system'
        },
        { transaction }
      );
    });
  },

  down: async (queryInterface, Sequelize) => {
    // Revert back to original enum without approval notification types
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.changeColumn(
        'notifications',
        'type',
        {
          type: Sequelize.ENUM(
            'task_assigned',
            'task_completed',
            'task_commented',
            'task_deadline_approaching',
            'task_status_changed',
            'task_review_pending',
            'task_review_approved',
            'task_review_rejected',
            'system'
          ),
          allowNull: false,
          defaultValue: 'system'
        },
        { transaction }
      );
    });
  }
};
