module.exports = (sequelize, DataTypes) => {
  const TaskReview = sequelize.define('TaskReview', {
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
    reviewer_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    status: {
      type: DataTypes.ENUM('approved', 'reopened'),
      allowNull: false
    },
    comment: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    rating: {
      type: DataTypes.DECIMAL(3, 1),
      allowNull: true
    },
    quality_score: {
      type: DataTypes.DECIMAL(3, 1),
      allowNull: true
    },
    timeliness_score: {
      type: DataTypes.DECIMAL(3, 1),
      allowNull: true
    },
    created_at: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'task_reviews',
    timestamps: false,
    underscored: true,
    indexes: [
      {
        fields: ['task_id']
      },
      {
        fields: ['reviewer_user_id']
      },
      {
        fields: ['created_at']
      }
    ]
  });

  TaskReview.associate = (models) => {
    TaskReview.belongsTo(models.Task, {
      foreignKey: 'task_id',
      as: 'task',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });

    TaskReview.belongsTo(models.User, {
      foreignKey: 'reviewer_user_id',
      as: 'reviewer',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });
  };

  return TaskReview;
};