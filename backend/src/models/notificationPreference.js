module.exports = (sequelize, DataTypes) => {
  const NotificationPreference = sequelize.define('NotificationPreference', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      unique: true,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    task_assigned: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_completed: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_commented: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_deadline_approaching: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_status_changed: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_review_pending: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_review_approved: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    task_review_rejected: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    email_notifications: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
    },
    push_notifications: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true
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
    tableName: 'notification_preferences',
    underscored: true,
    timestamps: true
  });

  NotificationPreference.associate = (models) => {
    NotificationPreference.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user'
    });
  };

  return NotificationPreference;
};
