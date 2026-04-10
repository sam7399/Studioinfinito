'use strict';

// Safety migration: ensures show_collaborators, escalation_level, last_escalation_at
// exist on the tasks table and task_assignments / task_dependencies tables exist.
// Fully idempotent — safe to run even if columns/tables already exist.
module.exports = {
  up: async (queryInterface, Sequelize) => {
    const taskCols = await queryInterface.describeTable('tasks');
    const allTables = await queryInterface.showAllTables();

    if (!taskCols.show_collaborators) {
      await queryInterface.addColumn('tasks', 'show_collaborators', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      });
    }

    if (!taskCols.escalation_level) {
      await queryInterface.addColumn('tasks', 'escalation_level', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      });
    }

    if (!taskCols.last_escalation_at) {
      await queryInterface.addColumn('tasks', 'last_escalation_at', {
        type: Sequelize.DATE,
        allowNull: true
      });
    }

    if (!allTables.includes('task_assignments')) {
      await queryInterface.createTable('task_assignments', {
        id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
        task_id: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'tasks', key: 'id' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
        },
        user_id: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'users', key: 'id' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
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

      await queryInterface.addIndex('task_assignments', ['task_id'], { name: 'ta2_task_id_idx' });
      await queryInterface.addIndex('task_assignments', ['user_id'], { name: 'ta2_user_id_idx' });
      await queryInterface.addIndex('task_assignments', ['task_id', 'user_id'], {
        name: 'ta2_task_user_unique',
        unique: true
      });
    }

    if (!allTables.includes('task_dependencies')) {
      await queryInterface.createTable('task_dependencies', {
        id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
        task_id: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'tasks', key: 'id' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
        },
        depends_on_task_id: {
          type: Sequelize.INTEGER,
          allowNull: false,
          references: { model: 'tasks', key: 'id' },
          onUpdate: 'CASCADE',
          onDelete: 'CASCADE'
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

      await queryInterface.addIndex('task_dependencies', ['task_id'], { name: 'td2_task_id_idx' });
      await queryInterface.addIndex('task_dependencies', ['task_id', 'depends_on_task_id'], {
        name: 'td2_unique',
        unique: true
      });
    }
  },

  down: async (queryInterface) => {
    // No-op: columns/tables may be shared with migration 000010
  }
};
