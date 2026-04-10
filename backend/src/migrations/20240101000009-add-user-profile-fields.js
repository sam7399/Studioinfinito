'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const tableDesc = await queryInterface.describeTable('users');

    // Add phone if missing
    if (!tableDesc.phone) {
      await queryInterface.addColumn('users', 'phone', {
        type: Sequelize.STRING(20),
        allowNull: true,
        after: 'name'
      });
    }

    // Add emp_code (employee ID / code)
    if (!tableDesc.emp_code) {
      await queryInterface.addColumn('users', 'emp_code', {
        type: Sequelize.STRING(50),
        allowNull: true,
        after: 'phone'
      });
      await queryInterface.addIndex('users', ['emp_code'], {
        unique: true,
        name: 'users_emp_code_unique'
      });
    }

    // Add username
    if (!tableDesc.username) {
      await queryInterface.addColumn('users', 'username', {
        type: Sequelize.STRING(100),
        allowNull: true,
        after: 'emp_code'
      });
      await queryInterface.addIndex('users', ['username'], {
        unique: true,
        name: 'users_username_unique'
      });
    }

    // Add designation (job title)
    if (!tableDesc.designation) {
      await queryInterface.addColumn('users', 'designation', {
        type: Sequelize.STRING(100),
        allowNull: true,
        after: 'username'
      });
    }

    // Add date_of_birth
    if (!tableDesc.date_of_birth) {
      await queryInterface.addColumn('users', 'date_of_birth', {
        type: Sequelize.DATEONLY,
        allowNull: true,
        after: 'designation'
      });
    }

    // Add department_head_id (FK to users)
    if (!tableDesc.department_head_id) {
      await queryInterface.addColumn('users', 'department_head_id', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
        after: 'manager_id'
      });
      await queryInterface.addIndex('users', ['department_head_id'], {
        name: 'users_department_head_id_idx'
      });
    }
  },

  down: async (queryInterface) => {
    await queryInterface.removeIndex('users', 'users_emp_code_unique').catch(() => {});
    await queryInterface.removeIndex('users', 'users_username_unique').catch(() => {});
    await queryInterface.removeIndex('users', 'users_department_head_id_idx').catch(() => {});

    for (const col of ['phone', 'emp_code', 'username', 'designation', 'date_of_birth', 'department_head_id']) {
      await queryInterface.removeColumn('users', col).catch(() => {});
    }
  }
};
