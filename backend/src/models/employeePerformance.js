module.exports = (sequelize, DataTypes) => {
  const EmployeePerformance = sequelize.define('EmployeePerformance', {
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
    department_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'departments', key: 'id' }
    },
    overall_rating: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: true,
      defaultValue: 0
    },
    task_completion_rate: {
      type: DataTypes.DECIMAL(5, 2),
      allowNull: true,
      defaultValue: 0
    },
    on_time_completion_rate: {
      type: DataTypes.DECIMAL(5, 2),
      allowNull: true,
      defaultValue: 0
    },
    average_quality_score: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: true,
      defaultValue: 0
    },
    strengths: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: []
    },
    weaknesses: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: []
    },
    improvement_areas: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: []
    },
    achievements: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: []
    },
    last_evaluated: {
      type: DataTypes.DATE,
      allowNull: true
    },
    evaluation_notes: {
      type: DataTypes.TEXT,
      allowNull: true
    }
  }, {
    tableName: 'employee_performance',
    timestamps: true,
    underscored: true
  });

  EmployeePerformance.associate = (models) => {
    EmployeePerformance.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
    EmployeePerformance.belongsTo(models.Department, {
      foreignKey: 'department_id',
      as: 'department',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
  };

  return EmployeePerformance;
};
