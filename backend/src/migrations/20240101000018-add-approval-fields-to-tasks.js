'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.sequelize.transaction(async (transaction) => {
      // Add approval_status column
      await queryInterface.addColumn(
        'tasks',
        'approval_status',
        {
          type: Sequelize.ENUM('pending', 'approved', 'rejected'),
          allowNull: true,
          defaultValue: null,
          comment: 'null = no approval requested, pending = waiting for approval, approved = task approved, rejected = task rejected'
        },
        { transaction }
      );

      // Add approver_id column (references user who approved)
      await queryInterface.addColumn(
        'tasks',
        'approver_id',
        {
          type: Sequelize.INTEGER,
          allowNull: true,
          references: {
            model: 'users',
            key: 'id'
          },
          onDelete: 'SET NULL',
          comment: 'User who approved or rejected the task'
        },
        { transaction }
      );

      // Add approval_comments column
      await queryInterface.addColumn(
        'tasks',
        'approval_comments',
        {
          type: Sequelize.TEXT,
          allowNull: true,
          comment: 'Comments from approver when approving'
        },
        { transaction }
      );

      // Add approval_date timestamp
      await queryInterface.addColumn(
        'tasks',
        'approval_date',
        {
          type: Sequelize.DATE,
          allowNull: true,
          comment: 'Timestamp when approval/rejection happened'
        },
        { transaction }
      );

      // Add rejection_reason column
      await queryInterface.addColumn(
        'tasks',
        'rejection_reason',
        {
          type: Sequelize.TEXT,
          allowNull: true,
          comment: 'Reason for rejection when approval_status is rejected'
        },
        { transaction }
      );

      // Add indexes for approval workflow queries
      await queryInterface.addIndex(
        'tasks',
        ['approval_status'],
        { transaction, name: 'idx_tasks_approval_status' }
      );

      await queryInterface.addIndex(
        'tasks',
        ['approver_id'],
        { transaction, name: 'idx_tasks_approver_id' }
      );

      await queryInterface.addIndex(
        'tasks',
        ['approval_status', 'approver_id'],
        { transaction, name: 'idx_tasks_approval_status_approver' }
      );
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.sequelize.transaction(async (transaction) => {
      // Remove indexes
      await queryInterface.removeIndex(
        'tasks',
        'idx_tasks_approval_status',
        { transaction }
      ).catch(() => {}); // Ignore if index doesn't exist

      await queryInterface.removeIndex(
        'tasks',
        'idx_tasks_approver_id',
        { transaction }
      ).catch(() => {});

      await queryInterface.removeIndex(
        'tasks',
        'idx_tasks_approval_status_approver',
        { transaction }
      ).catch(() => {});

      // Remove columns
      await queryInterface.removeColumn('tasks', 'approval_status', { transaction });
      await queryInterface.removeColumn('tasks', 'approver_id', { transaction });
      await queryInterface.removeColumn('tasks', 'approval_comments', { transaction });
      await queryInterface.removeColumn('tasks', 'approval_date', { transaction });
      await queryInterface.removeColumn('tasks', 'rejection_reason', { transaction });
    });
  }
};
