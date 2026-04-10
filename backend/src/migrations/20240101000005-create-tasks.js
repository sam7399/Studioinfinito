'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('tasks', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true
      },
      company_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'companies',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      department_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'departments',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      location_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'locations',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      created_by_user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      assigned_to_user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      title: {
        type: Sequelize.STRING(500),
        allowNull: false
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      priority: {
        type: Sequelize.ENUM('low', 'normal', 'high', 'urgent'),
        allowNull: false,
        defaultValue: 'normal'
      },
      status: {
        type: Sequelize.ENUM('open', 'in_progress', 'complete_pending_review', 'finalized', 'reopened'),
        allowNull: false,
        defaultValue: 'open'
      },
      due_date: {
        type: Sequelize.DATEONLY,
        allowNull: true
      },
      estimated_hours: {
        type: Sequelize.DECIMAL(6, 2),
        allowNull: true
      },
      progress_percent: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      completed_at: {
        type: Sequelize.DATE,
        allowNull: true
      },
      last_review_reminder_at: {
        type: Sequelize.DATE,
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
    }, {
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci'
    });

    await queryInterface.addIndex('tasks', ['company_id'], {
      name: 'tasks_company_id_idx'
    });

    await queryInterface.addIndex('tasks', ['department_id'], {
      name: 'tasks_department_id_idx'
    });

    await queryInterface.addIndex('tasks', ['location_id'], {
      name: 'tasks_location_id_idx'
    });

    await queryInterface.addIndex('tasks', ['created_by_user_id'], {
      name: 'tasks_created_by_user_id_idx'
    });

    await queryInterface.addIndex('tasks', ['assigned_to_user_id'], {
      name: 'tasks_assigned_to_user_id_idx'
    });

    await queryInterface.addIndex('tasks', ['status'], {
      name: 'tasks_status_idx'
    });

    await queryInterface.addIndex('tasks', ['priority'], {
      name: 'tasks_priority_idx'
    });

    await queryInterface.addIndex('tasks', ['due_date'], {
      name: 'tasks_due_date_idx'
    });

    await queryInterface.addIndex('tasks', ['completed_at'], {
      name: 'tasks_completed_at_idx'
    });

    await queryInterface.addIndex('tasks', ['status', 'completed_at'], {
      name: 'tasks_status_completed_at_idx'
    });

    await queryInterface.addIndex('tasks', ['status', 'last_review_reminder_at'], {
      name: 'tasks_status_last_review_reminder_at_idx'
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('tasks');
  }
};