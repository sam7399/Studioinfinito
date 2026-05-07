module.exports = (sequelize, DataTypes) => {
  const ChatRoom = sequelize.define('ChatRoom', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    type: {
      type: DataTypes.ENUM('direct', 'task', 'group'),
      allowNull: false,
      defaultValue: 'direct'
    },
    task_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'tasks', key: 'id' }
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    created_by_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    last_message_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'chat_rooms',
    underscored: true,
    timestamps: true,
    indexes: [
      { fields: ['task_id'] },
      { fields: ['type'] },
      { fields: ['last_message_at'] }
    ]
  });

  ChatRoom.associate = (models) => {
    ChatRoom.belongsTo(models.Task, { foreignKey: 'task_id', as: 'task' });
    ChatRoom.belongsTo(models.User, { foreignKey: 'created_by_user_id', as: 'creator' });
    ChatRoom.hasMany(models.ChatRoomMember, { foreignKey: 'room_id', as: 'members' });
    ChatRoom.hasMany(models.ChatMessage, { foreignKey: 'room_id', as: 'messages' });
    ChatRoom.belongsToMany(models.User, {
      through: models.ChatRoomMember,
      foreignKey: 'room_id',
      otherKey: 'user_id',
      as: 'users'
    });
  };

  return ChatRoom;
};
