module.exports = (sequelize, DataTypes) => {
  const Location = sequelize.define('Location', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    company_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'companies',
        key: 'id'
      }
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: [2, 255]
      }
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    }
  }, {
    tableName: 'locations',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['company_id', 'name']
      },
      {
        fields: ['company_id']
      },
      {
        fields: ['is_active']
      }
    ]
  });

  Location.associate = (models) => {
    Location.belongsTo(models.Company, {
      foreignKey: 'company_id',
      as: 'company',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Location.hasMany(models.User, {
      foreignKey: 'location_id',
      as: 'users',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Location.hasMany(models.Task, {
      foreignKey: 'location_id',
      as: 'tasks',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Location.belongsToMany(models.User, {
      through: models.UserLocation,
      foreignKey: 'location_id',
      otherKey: 'user_id',
      as: 'multi_users'
    });
  };

  return Location;
};