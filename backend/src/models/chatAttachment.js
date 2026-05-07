module.exports = (sequelize, DataTypes) => {
  const ChatAttachment = sequelize.define('ChatAttachment', {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    message_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'chat_messages', key: 'id' }
    },
    uploaded_by_user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    original_name: { type: DataTypes.STRING(255), allowNull: false },
    stored_name: { type: DataTypes.STRING(255), allowNull: false },
    mime_type: { type: DataTypes.STRING(100), allowNull: true },
    file_size: { type: DataTypes.INTEGER, allowNull: true }
  }, {
    tableName: 'chat_attachments',
    underscored: true,
    timestamps: true,
    indexes: [{ fields: ['message_id'] }]
  });

  ChatAttachment.associate = (models) => {
    ChatAttachment.belongsTo(models.ChatMessage, { foreignKey: 'message_id', as: 'message' });
    ChatAttachment.belongsTo(models.User, { foreignKey: 'uploaded_by_user_id', as: 'uploader' });
  };

  return ChatAttachment;
};
