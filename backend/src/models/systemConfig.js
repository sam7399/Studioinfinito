module.exports = (sequelize, DataTypes) => {
  const SystemConfig = sequelize.define('SystemConfig', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    key: { type: DataTypes.STRING(100), allowNull: false, unique: true },
    value: { type: DataTypes.TEXT, allowNull: false, defaultValue: 'false' },
    description: { type: DataTypes.STRING(255), allowNull: true }
  }, {
    tableName: 'system_configs',
    timestamps: true,
    underscored: true
  });
  return SystemConfig;
};
