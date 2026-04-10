'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('task_approvals', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      task_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'tasks',
          key: 'id'
        },
        onDelete: 'CASCADE'
      },
      approver_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id'
        },
        onDelete: 'RESTRICT',
        comment: 'Manager/Department Head who approved or rejected'
      },
      status: {
        type: Sequelize.ENUM('pending', 'approved', 'rejected'),
        allowNull: false,
        defaultValue: 'pending',
        comment: 'Current approval status'
      },
      comments: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Comments from approver (for approval) or reason (for rejection)'
      },
      reason: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Additional reason for rejection'
      },
      submitted_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn('NOW'),
        comment: 'When task was submitted for approval'
      },
      reviewed_at: {
        type: Sequelize.DATE,
        allowNull: true,
        comment: 'When approver reviewed the task'
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn('NOW')
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn('NOW')
      }
    });

    // Add indexes for efficient queries
    await queryInterface.addIndex('task_approvals', ['task_id']);
    await queryInterface.addIndex('task_approvals', ['approver_id']);
    await queryInterface.addIndex('task_approvals', ['status']);
    await queryInterface.addIndex('task_approvals', ['approver_id', 'status'], {
      name: 'idx_task_approvals_approver_status'
    });
    await queryInterface.addIndex('task_approvals', ['created_at']);
    await queryInterface.addIndex('task_approvals', ['task_id', 'status']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('task_approvals');
  }
};
