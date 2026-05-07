module.exports = (sequelize, DataTypes) => {
  const ChatRoomMember = sequelize.define('ChatRoomMember', {
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
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'users', key: 'id' }
    },
    last_read_at: {
      type: DataTypes.DATE,
      allowNull: true
    },
    muted: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    }
  }, {
    tableName: 'chat_room_members',
    underscored: true,
    timestamps: true,
    indexes: [
      { unique: true, fields: ['room_id', 'user_id'] },
      { fields: ['user_id'] }
    ]
  });

  ChatRoomMember.associate = (models) => {
    ChatRoomMember.belongsTo(models.ChatRoom, { foreignKey: 'room_id', as: 'room' });
    ChatRoomMember.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });
  };

  return ChatRoomMember;
};
