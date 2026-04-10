module.exports = (sequelize, DataTypes) => {
  const TaskMetrics = sequelize.define('TaskMetrics', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    tasks_completed: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    tasks_on_time: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    tasks_late: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    tasks_pending_review: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    average_completion_days: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: 0
    },
    average_quality_score: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: true,
      defaultValue: 0
    },
    rejection_count: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    period_start: {
      type: DataTypes.DATE,
      allowNull: false
    },
    period_end: {
      type: DataTypes.DATE,
      allowNull: false
    }
  }, {
    tableName: 'task_metrics',
    timestamps: true,
    underscored: true
  });

  TaskMetrics.associate = (models) => {
    TaskMetrics.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
  };

  return TaskMetrics;
};
