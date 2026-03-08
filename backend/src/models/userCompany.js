module.exports = (sequelize, DataTypes) => {
  const UserCompany = sequelize.define('UserCompany', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    user_id: { type: DataTypes.INTEGER, allowNull: false },
    company_id: { type: DataTypes.INTEGER, allowNull: false },
    is_primary: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false }
  }, {
    tableName: 'user_companies',
    timestamps: true,
    underscored: true
  });
  return UserCompany;
};
