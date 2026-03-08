'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const allTables = await queryInterface.showAllTables();
    if (allTables.includes('task_attachments')) return;

    await queryInterface.createTable('task_attachments', {
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
      uploaded_by_user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT'
      },
      original_name: {
        type: Sequelize.STRING(255),
        allowNull: false
      },
      stored_name: {
        type: Sequelize.STRING(255),
        allowNull: false
      },
      mime_type: {
        type: Sequelize.STRING(100),
        allowNull: true
      },
      file_size: {
        type: Sequelize.INTEGER,
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

    await queryInterface.addIndex('task_attachments', ['task_id'], { name: 'ta_attach_task_id_idx' });
  },

  down: async (queryInterface) => {
    await queryInterface.dropTable('task_attachments');
  }
};
