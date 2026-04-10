'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const allTables = await queryInterface.showAllTables();
    if (allTables.includes('department_metrics')) return;

    await queryInterface.createTable('department_metrics', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      department_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'departments', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      total_tasks: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      completed_tasks: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      on_time_tasks: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      late_tasks: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      on_time_percentage: {
        type: Sequelize.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0
      },
      completion_percentage: {
        type: Sequelize.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0
      },
      average_time_to_complete: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: true,
        defaultValue: 0
      },
      average_quality_score: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: true,
        defaultValue: 0
      },
      team_size: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      month: {
        type: Sequelize.INTEGER,
        allowNull: false
      },
      year: {
        type: Sequelize.INTEGER,
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

    await queryInterface.addIndex('department_metrics', ['department_id'], { name: 'dm_dept_id_idx' });
    await queryInterface.addIndex('department_metrics', ['month', 'year'], { name: 'dm_period_idx' });
  },

  down: async (queryInterface) => {
    await queryInterface.dropTable('department_metrics');
  }
};
