'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add new action types for task approval workflow to task_activities
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.changeColumn(
        'task_activities',
        'action',
        {
          type: Sequelize.ENUM('created', 'updated', 'assigned', 'completed', 'submitted_for_approval', 'approved', 'rejected', 'reopened'),
          allowNull: false
        },
        { transaction }
      );
    });
  },

  down: async (queryInterface, Sequelize) => {
    // Revert back to original enum without approval actions
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.changeColumn(
        'task_activities',
        'action',
        {
          type: Sequelize.ENUM('created', 'updated', 'assigned', 'completed', 'approved', 'reopened'),
          allowNull: false
        },
        { transaction }
      );
    });
  }
};
