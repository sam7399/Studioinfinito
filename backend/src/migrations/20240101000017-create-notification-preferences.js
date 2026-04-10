'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('notification_preferences', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        unique: true,
        references: {
          model: 'users',
          key: 'id'
        },
        onDelete: 'CASCADE'
      },
      task_assigned: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_completed: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_commented: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_deadline_approaching: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_status_changed: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_review_pending: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_review_approved: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      task_review_rejected: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      email_notifications: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      push_notifications: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
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

    // Add index for quick lookup
    await queryInterface.addIndex('notification_preferences', ['user_id']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('notification_preferences');
  }
};
