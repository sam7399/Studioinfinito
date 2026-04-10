module.exports = (sequelize, DataTypes) => {
  const TaskAttachment = sequelize.define('TaskAttachment', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    task_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'tasks', key: 'id' }
    },
    uploaded_by_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    original_name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    stored_name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    mime_type: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    file_size: {
      type: DataTypes.INTEGER,
      allowNull: true
    }
  }, {
    tableName: 'task_attachments',
    timestamps: true,
    underscored: true
  });

  TaskAttachment.associate = (models) => {
    TaskAttachment.belongsTo(models.Task, {
      foreignKey: 'task_id',
      as: 'task',
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    });
    TaskAttachment.belongsTo(models.User, {
      foreignKey: 'uploaded_by_user_id',
      as: 'uploader',
      onUpdate: 'CASCADE',
      onDelete: 'RESTRICT'
    });
  };

  return TaskAttachment;
};
