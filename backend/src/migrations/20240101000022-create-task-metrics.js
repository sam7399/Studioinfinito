'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const allTables = await queryInterface.showAllTables();
    if (allTables.includes('task_metrics')) return;

    await queryInterface.createTable('task_metrics', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      tasks_completed: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      tasks_on_time: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      tasks_late: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      tasks_pending_review: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      average_completion_days: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: true,
        defaultValue: 0
      },
      average_quality_score: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: true,
        defaultValue: 0
      },
      rejection_count: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      period_start: {
        type: Sequelize.DATE,
        allowNull: false
      },
      period_end: {
        type: Sequelize.DATE,
        allowNull: false
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
      }
    }, { charset: 'utf8mb4', collate: 'utf8mb4_unicode_ci' });

    await queryInterface.addIndex('task_metrics', ['user_id'], { name: 'tm_user_id_idx' });
    await queryInterface.addIndex('task_metrics', ['period_start', 'period_end'], { name: 'tm_period_idx' });
  },

  down: async (queryInterface) => {
    await queryInterface.dropTable('task_metrics');
  }
};
