'use strict';
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('user_locations', {
      id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
      user_id: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      location_id: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'locations', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      is_primary: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP') }
    });
    await queryInterface.addIndex('user_locations', ['user_id', 'location_id'], { unique: true, name: 'ul_user_location_unique' });
  },
  down: async (queryInterface) => {
    await queryInterface.dropTable('user_locations');
  }
};
