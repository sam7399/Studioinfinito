module.exports = (sequelize, DataTypes) => {
  const TaskAssignment = sequelize.define('TaskAssignment', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    task_id: { type: DataTypes.INTEGER, allowNull: false },
    user_id: { type: DataTypes.INTEGER, allowNull: false }
  }, {
    tableName: 'task_assignments',
    timestamps: true,
    underscored: true
  });

  TaskAssignment.associate = (models) => {
    TaskAssignment.belongsTo(models.Task, { foreignKey: 'task_id', as: 'task' });
    TaskAssignment.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });
  };

  return TaskAssignment;
};
