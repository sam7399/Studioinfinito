'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      // Add reopen_count to track how many times a task has been reopened
      await queryInterface.addColumn('tasks', 'reopen_count', {
        type: Sequelize.INTEGER,
        defaultValue: 0,
        allowNull: false
      }, { transaction });

      // Add last_reopened_at timestamp
      await queryInterface.addColumn('tasks', 'last_reopened_at', {
        type: Sequelize.DATE,
        allowNull: true
      }, { transaction });

      // Add first_completed_at to track initial completion
      await queryInterface.addColumn('tasks', 'first_completed_at', {
        type: Sequelize.DATE,
        allowNull: true
      }, { transaction });

      // Add index for audit queries
      await queryInterface.addIndex('tasks', ['reopen_count'], {
        name: 'idx_tasks_reopen_count',
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.removeIndex('tasks', 'idx_tasks_reopen_count', { transaction });
      await queryInterface.removeColumn('tasks', 'first_completed_at', { transaction });
      await queryInterface.removeColumn('tasks', 'last_reopened_at', { transaction });
      await queryInterface.removeColumn('tasks', 'reopen_count', { transaction });
    });
  }
};
