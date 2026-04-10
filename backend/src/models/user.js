const bcrypt = require('bcrypt');

module.exports = (sequelize, DataTypes) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    company_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'companies',
        key: 'id'
      }
    },
    department_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'departments',
        key: 'id'
      }
    },
    location_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'locations',
        key: 'id'
      }
    },
    manager_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    department_head_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'users',
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
    email: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      },
      set(value) {
        this.setDataValue('email', value.toLowerCase());
      }
    },
    password_hash: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    role: {
      type: DataTypes.ENUM('superadmin', 'management', 'department_head', 'manager', 'employee'),
      allowNull: false,
      defaultValue: 'employee'
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    force_password_change: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    },
    phone: {
      type: DataTypes.STRING(20),
      allowNull: true
    },
    emp_code: {
      type: DataTypes.STRING(50),
      allowNull: true,
      unique: true
    },
    username: {
      type: DataTypes.STRING(100),
      allowNull: true,
      unique: true
    },
    designation: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    date_of_birth: {
      type: DataTypes.DATEONLY,
      allowNull: true
    },
    last_login_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'users',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        unique: true,
        fields: ['email']
      },
      {
        fields: ['company_id']
      },
      {
        fields: ['department_id']
      },
      {
        fields: ['location_id']
      },
      {
        fields: ['manager_id']
      },
      {
        fields: ['role']
      },
      {
        fields: ['is_active']
      }
    ],
    hooks: {
      beforeCreate: async (user) => {
        if (user.password_hash && !user.password_hash.startsWith('$2')) {
          user.password_hash = await bcrypt.hash(user.password_hash, 10);
        }
      },
      beforeUpdate: async (user) => {
        if (user.changed('password_hash') && !user.password_hash.startsWith('$2')) {
          user.password_hash = await bcrypt.hash(user.password_hash, 10);
        }
      }
    }
  });

  User.associate = (models) => {
    User.belongsTo(models.Company, {
      foreignKey: 'company_id',
      as: 'company',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.belongsTo(models.Department, {
      foreignKey: 'department_id',
      as: 'department',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.belongsTo(models.Location, {
      foreignKey: 'location_id',
      as: 'location',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.belongsTo(models.User, {
      foreignKey: 'manager_id',
      as: 'manager',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.hasMany(models.User, {
      foreignKey: 'manager_id',
      as: 'team_members',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.belongsTo(models.User, {
      foreignKey: 'department_head_id',
      as: 'department_head',
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL'
    });

    User.hasMany(models.Task, {
      foreignKey: 'created_by_user_id',
      as: 'created_tasks',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.hasMany(models.Task, {
      foreignKey: 'assigned_to_user_id',
      as: 'assigned_tasks',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.hasMany(models.TaskReview, {
      foreignKey: 'reviewer_user_id',
      as: 'reviews',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.hasMany(models.TaskActivity, {
      foreignKey: 'actor_user_id',
      as: 'activities',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    User.hasMany(models.PasswordResetToken, {
      foreignKey: 'user_id',
      as: 'reset_tokens',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    User.belongsToMany(models.Company, {
      through: models.UserCompany,
      foreignKey: 'user_id',
      otherKey: 'company_id',
      as: 'companies'
    });
    User.belongsToMany(models.Location, {
      through: models.UserLocation,
      foreignKey: 'user_id',
      otherKey: 'location_id',
      as: 'locations'
    });
  };

  // Instance methods
  User.prototype.comparePassword = async function(candidatePassword) {
    return bcrypt.compare(candidatePassword, this.password_hash);
  };

  User.prototype.toJSON = function() {
    const values = { ...this.get() };
    delete values.password_hash;
    return values;
  };

  return User;
};