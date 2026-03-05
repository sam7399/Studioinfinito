module.exports = (sequelize, DataTypes) => {
  const TaskDependency = sequelize.define('TaskDependency', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    task_id: { type: DataTypes.INTEGER, allowNull: false },
    depends_on_task_id: { type: DataTypes.INTEGER, allowNull: false }
  }, {
    tableName: 'task_dependencies',
    timestamps: true,
    underscored: true
  });

  TaskDependency.associate = (models) => {
    TaskDependency.belongsTo(models.Task, { foreignKey: 'task_id', as: 'task' });
    TaskDependency.belongsTo(models.Task, { foreignKey: 'depends_on_task_id', as: 'dependsOn' });
  };

  return TaskDependency;
};
