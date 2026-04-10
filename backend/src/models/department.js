module.exports = (sequelize, DataTypes) => {
  const Department = sequelize.define('Department', {
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
    tableName: 'departments',
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

  Department.associate = (models) => {
    Department.belongsTo(models.Company, {
      foreignKey: 'company_id',
      as: 'company',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Department.hasMany(models.User, {
      foreignKey: 'department_id',
      as: 'users',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Department.hasMany(models.Task, {
      foreignKey: 'department_id',
      as: 'tasks',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });
  };

  return Department;
};