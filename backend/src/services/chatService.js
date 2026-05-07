const { Op } = require('sequelize');
const {
  sequelize,
  ChatRoom,
  ChatRoomMember,
  ChatMessage,
  User,
  Task
} = require('../models');
const logger = require('../utils/logger');

const USER_ATTRS = ['id', 'name', 'email', 'role', 'department_id'];

function emitToRoom(io, roomId, event, payload) {
  if (!io) return;
  io.to(`chat:${roomId}`).emit(event, payload);
}

async function ensureMembership(roomId, userId) {
  const member = await ChatRoomMember.findOne({ where: { room_id: roomId, user_id: userId } });
  if (!member) throw new Error('Not a member of this room');
  return member;
}

async function attachMembers(room) {
  const members = await ChatRoomMember.findAll({
    where: { room_id: room.id },
    include: [{ model: User, as: 'user', attributes: USER_ATTRS }]
  });
  return { ...room.toJSON(), members: members.map(m => m.toJSON()) };
}

class ChatService {
  /**
   * List rooms a user belongs to, with last message + unread count.
   */
  static async listRooms(user) {
    const memberships = await ChatRoomMember.findAll({
      where: { user_id: user.id },
      include: [{
        model: ChatRoom,
        as: 'room',
        include: [
          { model: Task, as: 'task', attributes: ['id', 'title', 'status'] }
        ]
      }],
      order: [[{ model: ChatRoom, as: 'room' }, 'last_message_at', 'DESC']]
    });

    const roomIds = memberships.map(m => m.room_id);
    if (roomIds.length === 0) return [];

    const lastMessages = await ChatMessage.findAll({
      where: { room_id: { [Op.in]: roomIds }, deleted_at: null },
      attributes: ['id', 'room_id', 'body', 'sender_user_id', 'message_type', 'created_at'],
      order: [['created_at', 'DESC']],
      include: [{ model: User, as: 'sender', attributes: ['id', 'name'] }]
    });

    const lastByRoom = {};
    for (const m of lastMessages) {
      if (!lastByRoom[m.room_id]) lastByRoom[m.room_id] = m.toJSON();
    }

    const unreadCounts = await Promise.all(memberships.map(async (mem) => {
      const where = { room_id: mem.room_id, deleted_at: null, sender_user_id: { [Op.ne]: user.id } };
      if (mem.last_read_at) where.created_at = { [Op.gt]: mem.last_read_at };
      const count = await ChatMessage.count({ where });
      return [mem.room_id, count];
    }));
    const unreadByRoom = Object.fromEntries(unreadCounts);

    const roomMembers = await ChatRoomMember.findAll({
      where: { room_id: { [Op.in]: roomIds } },
      include: [{ model: User, as: 'user', attributes: USER_ATTRS }]
    });
    const membersByRoom = {};
    for (const rm of roomMembers) {
      if (!membersByRoom[rm.room_id]) membersByRoom[rm.room_id] = [];
      membersByRoom[rm.room_id].push(rm.toJSON());
    }

    return memberships.map(m => {
      const room = m.room.toJSON();
      return {
        ...room,
        members: membersByRoom[room.id] || [],
        last_message: lastByRoom[room.id] || null,
        unread_count: unreadByRoom[room.id] || 0,
        last_read_at: m.last_read_at
      };
    });
  }

  /**
   * Get/create a 1-1 direct room between current user and target user.
   */
  static async getOrCreateDirectRoom(user, targetUserId) {
    if (targetUserId === user.id) throw new Error('Cannot chat with yourself');
    const target = await User.findByPk(targetUserId);
    if (!target) throw new Error('Target user not found');

    const userIds = [user.id, targetUserId].sort((a, b) => a - b);
    const existing = await sequelize.query(
      `SELECT cr.id FROM chat_rooms cr
       JOIN chat_room_members m1 ON m1.room_id = cr.id AND m1.user_id = :u1
       JOIN chat_room_members m2 ON m2.room_id = cr.id AND m2.user_id = :u2
       WHERE cr.type = 'direct'
       LIMIT 1`,
      {
        replacements: { u1: userIds[0], u2: userIds[1] },
        type: sequelize.QueryTypes.SELECT
      }
    );

    if (existing.length > 0) {
      const room = await ChatRoom.findByPk(existing[0].id);
      return attachMembers(room);
    }

    const tx = await sequelize.transaction();
    try {
      const room = await ChatRoom.create({
        type: 'direct',
        created_by_user_id: user.id,
        last_message_at: new Date()
      }, { transaction: tx });
      await ChatRoomMember.bulkCreate([
        { room_id: room.id, user_id: user.id },
        { room_id: room.id, user_id: targetUserId }
      ], { transaction: tx });
      await tx.commit();
      return attachMembers(room);
    } catch (err) {
      await tx.rollback();
      throw err;
    }
  }

  /**
   * Get/create a chat room scoped to a task (creator + assignee + collaborators).
   */
  static async getOrCreateTaskRoom(user, taskId) {
    const task = await Task.findByPk(taskId);
    if (!task) throw new Error('Task not found');

    let room = await ChatRoom.findOne({ where: { task_id: taskId, type: 'task' } });
    const memberIds = new Set();
    if (task.created_by_user_id) memberIds.add(task.created_by_user_id);
    if (task.assigned_to_user_id) memberIds.add(task.assigned_to_user_id);
    memberIds.add(user.id);

    if (!room) {
      const tx = await sequelize.transaction();
      try {
        room = await ChatRoom.create({
          type: 'task',
          task_id: taskId,
          name: task.title,
          created_by_user_id: user.id,
          last_message_at: new Date()
        }, { transaction: tx });
        const rows = [...memberIds].map(uid => ({ room_id: room.id, user_id: uid }));
        await ChatRoomMember.bulkCreate(rows, { transaction: tx });
        await tx.commit();
      } catch (err) {
        await tx.rollback();
        throw err;
      }
    } else {
      // Ensure caller is a member
      const existing = await ChatRoomMember.findOne({ where: { room_id: room.id, user_id: user.id } });
      if (!existing) {
        await ChatRoomMember.create({ room_id: room.id, user_id: user.id });
      }
    }

    return attachMembers(room);
  }

  /**
   * Get paginated messages of a room (newest first by default).
   */
  static async getMessages(roomId, user, { limit = 50, beforeId = null } = {}) {
    await ensureMembership(roomId, user.id);

    const where = { room_id: roomId, deleted_at: null };
    if (beforeId) where.id = { [Op.lt]: beforeId };

    const messages = await ChatMessage.findAll({
      where,
      order: [['id', 'DESC']],
      limit: Math.min(parseInt(limit) || 50, 100),
      include: [
        { model: User, as: 'sender', attributes: ['id', 'name', 'role'] },
        { model: ChatMessage, as: 'reply_to', attributes: ['id', 'body', 'sender_user_id'] }
      ]
    });

    return messages.reverse().map(m => m.toJSON());
  }

  /**
   * Send a message to a room.
   */
  static async sendMessage(roomId, user, { body, message_type = 'text', reply_to_id = null }, io) {
    await ensureMembership(roomId, user.id);
    if (!body || !body.trim()) throw new Error('Message body is required');

    const message = await ChatMessage.create({
      room_id: roomId,
      sender_user_id: user.id,
      body: body.trim(),
      message_type,
      reply_to_id
    });

    await ChatRoom.update({ last_message_at: message.created_at }, { where: { id: roomId } });
    await ChatRoomMember.update(
      { last_read_at: message.created_at },
      { where: { room_id: roomId, user_id: user.id } }
    );

    const full = await ChatMessage.findByPk(message.id, {
      include: [{ model: User, as: 'sender', attributes: ['id', 'name', 'role'] }]
    });
    const payload = full.toJSON();

    emitToRoom(io, roomId, 'chat:message_new', payload);

    // Notify each member's personal room so list view updates even if not in room
    const members = await ChatRoomMember.findAll({ where: { room_id: roomId } });
    if (io) {
      for (const m of members) {
        io.to(`user:${m.user_id}`).emit('chat:room_updated', {
          room_id: roomId,
          last_message: payload
        });
      }
    }

    return payload;
  }

  static async markRead(roomId, user, io) {
    const member = await ensureMembership(roomId, user.id);
    member.last_read_at = new Date();
    await member.save();
    emitToRoom(io, roomId, 'chat:read', { room_id: roomId, user_id: user.id, read_at: member.last_read_at });
    return { last_read_at: member.last_read_at };
  }

  static async editMessage(messageId, user, body, io) {
    const message = await ChatMessage.findByPk(messageId);
    if (!message || message.deleted_at) throw new Error('Message not found');
    if (message.sender_user_id !== user.id) throw new Error('You can only edit your own messages');
    if (!body || !body.trim()) throw new Error('Body required');

    message.body = body.trim();
    message.edited_at = new Date();
    await message.save();
    emitToRoom(io, message.room_id, 'chat:message_edited', message.toJSON());
    return message.toJSON();
  }

  static async deleteMessage(messageId, user, io) {
    const message = await ChatMessage.findByPk(messageId);
    if (!message || message.deleted_at) throw new Error('Message not found');
    if (message.sender_user_id !== user.id) throw new Error('You can only delete your own messages');
    message.deleted_at = new Date();
    await message.save();
    emitToRoom(io, message.room_id, 'chat:message_deleted', { id: message.id, room_id: message.room_id });
    return { success: true };
  }

  static async getUnreadTotal(user) {
    const memberships = await ChatRoomMember.findAll({ where: { user_id: user.id } });
    if (memberships.length === 0) return 0;
    let total = 0;
    for (const mem of memberships) {
      const where = { room_id: mem.room_id, deleted_at: null, sender_user_id: { [Op.ne]: user.id } };
      if (mem.last_read_at) where.created_at = { [Op.gt]: mem.last_read_at };
      total += await ChatMessage.count({ where });
    }
    return total;
  }
}

module.exports = ChatService;
