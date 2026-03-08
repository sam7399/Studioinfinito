'use strict';
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('user_companies', {
      id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
      user_id: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      company_id: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'companies', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      is_primary: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP') }
    });
    await queryInterface.addIndex('user_companies', ['user_id', 'company_id'], { unique: true, name: 'uc_user_company_unique' });
  },
  down: async (queryInterface) => {
    await queryInterface.dropTable('user_companies');
  }
};
