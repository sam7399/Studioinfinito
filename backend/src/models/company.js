module.exports = (sequelize, DataTypes) => {
  const Company = sequelize.define('Company', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: true,
        len: [2, 255]
      }
    },
    domain: {
      type: DataTypes.STRING(255),
      allowNull: true,
      validate: {
        isUrl: true
      }
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    }
  }, {
    tableName: 'companies',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['name']
      },
      {
        fields: ['is_active']
      }
    ]
  });

  Company.associate = (models) => {
    Company.hasMany(models.Department, {
      foreignKey: 'company_id',
      as: 'departments',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Company.hasMany(models.Location, {
      foreignKey: 'company_id',
      as: 'locations',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Company.hasMany(models.User, {
      foreignKey: 'company_id',
      as: 'users',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Company.hasMany(models.Task, {
      foreignKey: 'company_id',
      as: 'tasks',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Company.belongsToMany(models.User, {
      through: models.UserCompany,
      foreignKey: 'company_id',
      otherKey: 'user_id',
      as: 'multi_users'
    });
  };

  return Company;
};