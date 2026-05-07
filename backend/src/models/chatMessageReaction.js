module.exports = (sequelize, DataTypes) => {
  const ChatMessageReaction = sequelize.define('ChatMessageReaction', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    message_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'chat_messages', key: 'id' }
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    emoji: { type: DataTypes.STRING(16), allowNull: false }
  }, {
    tableName: 'chat_message_reactions',
    underscored: true,
    timestamps: true,
    indexes: [
      { unique: true, fields: ['message_id', 'user_id', 'emoji'] },
      { fields: ['message_id'] }
    ]
  });

  ChatMessageReaction.associate = (models) => {
    ChatMessageReaction.belongsTo(models.ChatMessage, { foreignKey: 'message_id', as: 'message' });
    ChatMessageReaction.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });
  };

  return ChatMessageReaction;
};
