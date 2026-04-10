module.exports = (sequelize, DataTypes) => {
  const TaskActivity = sequelize.define('TaskActivity', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    task_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'tasks',
        key: 'id'
      }
    },
    actor_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    action: {
      type: DataTypes.ENUM('created', 'updated', 'assigned', 'completed', 'submitted_for_approval', 'approved', 'rejected', 'reopened'),
      allowNull: false
    },
    note: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    created_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'task_activities',
    timestamps: false,
    underscored: true,
    indexes: [
      {
        fields: ['task_id']
      },
      {
        fields: ['actor_user_id']
      },
      {
        fields: ['action']
      },
      {
        fields: ['created_at']
      }
    ]
  });

  TaskActivity.associate = (models) => {
    TaskActivity.belongsTo(models.Task, {
      foreignKey: 'task_id',
      as: 'task',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    TaskActivity.belongsTo(models.User, {
      foreignKey: 'actor_user_id',
      as: 'actor',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });
  };

  return TaskActivity;
};