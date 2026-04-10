'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const allTables = await queryInterface.showAllTables();
    if (allTables.includes('employee_performance')) return;

    await queryInterface.createTable('employee_performance', {
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
      department_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'departments', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      overall_rating: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: true,
        defaultValue: 0
      },
      task_completion_rate: {
        type: Sequelize.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0
      },
      on_time_completion_rate: {
        type: Sequelize.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0
      },
      average_quality_score: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: true,
        defaultValue: 0
      },
      strengths: {
        type: Sequelize.JSON,
        allowNull: true,
        defaultValue: []
      },
      weaknesses: {
        type: Sequelize.JSON,
        allowNull: true,
        defaultValue: []
      },
      improvement_areas: {
        type: Sequelize.JSON,
        allowNull: true,
        defaultValue: []
      },
      achievements: {
        type: Sequelize.JSON,
        allowNull: true,
        defaultValue: []
      },
      last_evaluated: {
        type: Sequelize.DATE,
        allowNull: true
      },
      evaluation_notes: {
        type: Sequelize.TEXT,
        allowNull: true
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

    await queryInterface.addIndex('employee_performance', ['user_id'], { name: 'ep_user_id_idx' });
    await queryInterface.addIndex('employee_performance', ['department_id'], { name: 'ep_dept_id_idx' });
    await queryInterface.addIndex('employee_performance', ['overall_rating'], { name: 'ep_rating_idx' });
  },

  down: async (queryInterface) => {
    await queryInterface.dropTable('employee_performance');
  }
};
