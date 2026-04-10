module.exports = (sequelize, DataTypes) => {
  const TaskApproval = sequelize.define('TaskApproval', {
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
    approver_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      },
      comment: 'Manager/Department Head who approved or rejected'
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected'),
      allowNull: false,
      defaultValue: 'pending',
      comment: 'Current approval status'
    },
    comments: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Comments from approver (for approval) or reason (for rejection)'
    },
    reason: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Additional reason for rejection'
    },
    submitted_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
      comment: 'When task was submitted for approval'
    },
    reviewed_at: {
      type: DataTypes.DATE,
      allowNull: true,
      comment: 'When approver reviewed the task'
    }
  }, {
    tableName: 'task_approvals',
    timestamps: true,
    underscored: true,
    indexes: [
      {
        fields: ['task_id']
      },
      {
        fields: ['approver_id']
      },
      {
        fields: ['status']
      },
      {
        fields: ['approver_id', 'status']
      },
      {
        fields: ['created_at']
      },
      {
        fields: ['task_id', 'status']
      }
    ]
  });

  TaskApproval.associate = (models) => {
    TaskApproval.belongsTo(models.Task, {
      foreignKey: 'task_id',
      as: 'task',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    TaskApproval.belongsTo(models.User, {
      foreignKey: 'approver_id',
      as: 'approver',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });
  };

  return TaskApproval;
};
