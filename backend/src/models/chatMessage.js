module.exports = (sequelize, DataTypes) => {
  const ChatMessage = sequelize.define('ChatMessage', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    room_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'chat_rooms', key: 'id' }
    },
    sender_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    body: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    message_type: {
      type: DataTypes.ENUM('text', 'image', 'file', 'audio', 'system'),
      allowNull: false,
      defaultValue: 'text'
    },
    reply_to_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'chat_messages', key: 'id' }
    },
    edited_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    deleted_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    pinned_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    pinned_by_user_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'users', key: 'id' }
    },
    forwarded_from_message_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'chat_messages', key: 'id' }
    }
  }, {
    tableName: 'chat_messages',
    underscored: true,
    timestamps: true,
    indexes: [
      { fields: ['room_id', 'created_at'] },
      { fields: ['sender_user_id'] }
    ]
  });

  ChatMessage.associate = (models) => {
    ChatMessage.belongsTo(models.ChatRoom, { foreignKey: 'room_id', as: 'room' });
    ChatMessage.belongsTo(models.User, { foreignKey: 'sender_user_id', as: 'sender' });
    ChatMessage.belongsTo(models.ChatMessage, { foreignKey: 'reply_to_id', as: 'reply_to' });
    ChatMessage.hasMany(models.ChatAttachment, { foreignKey: 'message_id', as: 'attachments' });
    ChatMessage.hasMany(models.ChatMessageReaction, { foreignKey: 'message_id', as: 'reactions' });
  };

  return ChatMessage;
};
