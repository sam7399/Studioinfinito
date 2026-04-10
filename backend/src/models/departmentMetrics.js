module.exports = (sequelize, DataTypes) => {
  const DepartmentMetrics = sequelize.define('DepartmentMetrics', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    department_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'departments', key: 'id' }
    },
    total_tasks: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    completed_tasks: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    on_time_tasks: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    late_tasks: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    on_time_percentage: {
      type: DataTypes.DECIMAL(5, 2),
      allowNull: true,
      defaultValue: 0
    },
    completion_percentage: {
      type: DataTypes.DECIMAL(5, 2),
      allowNull: true,
      defaultValue: 0
    },
    average_time_to_complete: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: 0
    },
    average_quality_score: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: true,
      defaultValue: 0
    },
    team_size: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    },
    month: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    year: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    tableName: 'department_metrics',
    timestamps: true,
    underscored: true
  });

  DepartmentMetrics.associate = (models) => {
    DepartmentMetrics.belongsTo(models.Department, {
      foreignKey: 'department_id',
      as: 'department',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
  };

  return DepartmentMetrics;
};
