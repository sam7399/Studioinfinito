'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Check existing columns to make migration idempotent
    const taskCols = await queryInterface.describeTable('tasks');
    const allTables = await queryInterface.showAllTables();

    // 1. Add show_collaborators if not exists
    if (!taskCols.show_collaborators) {
      await queryInterface.addColumn('tasks', 'show_collaborators', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      });
    }

    // 2. Add escalation_level if not exists
    if (!taskCols.escalation_level) {
      await queryInterface.addColumn('tasks', 'escalation_level', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      });
    }

    // 3. Add last_escalation_at if not exists
    if (!taskCols.last_escalation_at) {
      await queryInterface.addColumn('tasks', 'last_escalation_at', {
        type: Sequelize.DATE,
        allowNull: true
      });
    }

    // 4. Create task_assignments table if not exists
    if (!allTables.includes('task_assignments')) {
      await queryInterface.createTable('task_assignments', {
        id: {
          type: Sequelize.INTEGER,
          primaryKey: true,
          autoIncrement: true
        },
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

      await queryInterface.addIndex('task_assignments', ['task_id'], { name: 'ta_task_id_idx' });
      await queryInterface.addIndex('task_assignments', ['user_id'], { name: 'ta_user_id_idx' });
      await queryInterface.addIndex('task_assignments', ['task_id', 'user_id'], {
        name: 'ta_task_user_unique',
        unique: true
      });
    }

    // 5. Create task_dependencies table if not exists
    if (!allTables.includes('task_dependencies')) {
      await queryInterface.createTable('task_dependencies', {
        id: {
          type: Sequelize.INTEGER,
          primaryKey: true,
          autoIncrement: true
        },
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

      await queryInterface.addIndex('task_dependencies', ['task_id'], { name: 'td_task_id_idx' });
      await queryInterface.addIndex('task_dependencies', ['task_id', 'depends_on_task_id'], {
        name: 'td_unique',
        unique: true
      });
    }
  },

  down: async (queryInterface) => {
    await queryInterface.dropTable('task_dependencies');
    await queryInterface.dropTable('task_assignments');
    await queryInterface.removeColumn('tasks', 'last_escalation_at');
    await queryInterface.removeColumn('tasks', 'escalation_level');
    await queryInterface.removeColumn('tasks', 'show_collaborators');
  }
};
