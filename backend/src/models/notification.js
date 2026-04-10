module.exports = (sequelize, DataTypes) => {
  const Notification = sequelize.define('Notification', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    task_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'tasks',
        key: 'id'
      }
    },
    type: {
      // BUG-002 FIX: Added approval notification types to match migration schema
      type: DataTypes.ENUM(
        'task_assigned',
        'task_completed',
        'task_commented',
        'task_deadline_approaching',
        'task_status_changed',
        'task_review_pending',
        'task_review_approved',
        'task_review_rejected',
        'task_approval_pending',
        'task_approval_approved',
        'task_approval_rejected',
        'task_reopened',
        'system'
      ),
      allowNull: false,
      defaultValue: 'system'
    },
    title: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: true,
      comment: 'Additional data like action_user_id, previous_status, etc.'
    },
    read: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    },
    read_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    createdAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'notifications',
    underscored: true,
    timestamps: true
  });

  Notification.associate = (models) => {
    Notification.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user'
    });

    Notification.belongsTo(models.Task, {
      foreignKey: 'task_id',
      as: 'task'
    });
  };

  return Notification;
};
