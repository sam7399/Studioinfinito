module.exports = (sequelize, DataTypes) => {
  const UserLocation = sequelize.define('UserLocation', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    location_id: { type: DataTypes.INTEGER, allowNull: false },
    is_primary: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false }
  }, {
    tableName: 'user_locations',
    timestamps: true,
    underscored: true
  });
  return UserLocation;
};
