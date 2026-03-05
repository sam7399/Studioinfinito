module.exports = (sequelize, DataTypes) => {
  const Task = sequelize.define('Task', {
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
    department_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'departments',
        key: 'id'
      }
    },
    location_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'locations',
        key: 'id'
      }
    },
    created_by_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    assigned_to_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    title: {
      type: DataTypes.STRING(500),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: [3, 500]
      }
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    priority: {
      type: DataTypes.ENUM('low', 'normal', 'high', 'urgent'),
      allowNull: false,
      defaultValue: 'normal'
    },
    status: {
      type: DataTypes.ENUM('open', 'in_progress', 'complete_pending_review', 'finalized', 'reopened'),
      allowNull: false,
      defaultValue: 'open'
    },
    due_date: {
      type: DataTypes.DATEONLY,
      allowNull: true
    },
    estimated_hours: {
      type: DataTypes.DECIMAL(6, 2),
      allowNull: true,
      validate: {
        min: 0,
        max: 9999.99
      }
    },
    progress_percent: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
        max: 100
      }
    },
    completed_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    last_review_reminder_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    show_collaborators: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    escalation_level: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    last_escalation_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'tasks',
    timestamps: true,
    underscored: true,
    indexes: [
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
        fields: ['created_by_user_id']
      },
      {
        fields: ['assigned_to_user_id']
      },
      {
        fields: ['status']
      },
      {
        fields: ['priority']
      },
      {
        fields: ['due_date']
      },
      {
        fields: ['completed_at']
      },
      {
        fields: ['status', 'completed_at']
      },
      {
        fields: ['status', 'last_review_reminder_at']
      }
    ]
  });

  Task.associate = (models) => {
    Task.belongsTo(models.Company, {
      foreignKey: 'company_id',
      as: 'company',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Task.belongsTo(models.Department, {
      foreignKey: 'department_id',
      as: 'department',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Task.belongsTo(models.Location, {
      foreignKey: 'location_id',
      as: 'location',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Task.belongsTo(models.User, {
      foreignKey: 'created_by_user_id',
      as: 'creator',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Task.belongsTo(models.User, {
      foreignKey: 'assigned_to_user_id',
      as: 'assignee',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });

    Task.hasMany(models.TaskReview, {
      foreignKey: 'task_id',
      as: 'reviews',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    Task.hasMany(models.TaskActivity, {
      foreignKey: 'task_id',
      as: 'activities',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    Task.hasMany(models.TaskAssignment, {
      foreignKey: 'task_id',
      as: 'assignments',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    Task.belongsToMany(models.User, {
      through: models.TaskAssignment,
      foreignKey: 'task_id',
      otherKey: 'user_id',
      as: 'collaborators'
    });

    Task.hasMany(models.TaskDependency, {
      foreignKey: 'task_id',
      as: 'dependencies',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
  };

  return Task;
};