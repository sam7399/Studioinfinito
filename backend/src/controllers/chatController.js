const ChatService = require('../services/chatService');
const logger = require('../utils/logger');

const getIo = () => global.io;

exports.listRooms = async (req, res, next) => {
  try {
    const rooms = await ChatService.listRooms(req.user);
    return res.status(200).json({ success: true, data: rooms });
  } catch (err) {
    logger.error('chat.listRooms', { err: err.message });
    next(err);
  }
};

exports.getMessages = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const { limit, before_id } = req.query;
    const messages = await ChatService.getMessages(roomId, req.user, {
      limit: limit ? parseInt(limit, 10) : 50,
      beforeId: before_id ? parseInt(before_id, 10) : null
    });
    return res.status(200).json({ success: true, data: messages });
  } catch (err) {
    logger.error('chat.getMessages', { err: err.message });
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.createDirectRoom = async (req, res, next) => {
  try {
    const { user_id } = req.body;
    const room = await ChatService.getOrCreateDirectRoom(req.user, parseInt(user_id, 10));
    return res.status(200).json({ success: true, data: room });
  } catch (err) {
    logger.error('chat.createDirectRoom', { err: err.message });
    if (err.message.includes('Cannot chat with yourself') || err.message.includes('not found')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.getOrCreateTaskRoom = async (req, res, next) => {
  try {
    const taskId = parseInt(req.params.taskId, 10);
    const room = await ChatService.getOrCreateTaskRoom(req.user, taskId);
    return res.status(200).json({ success: true, data: room });
  } catch (err) {
    logger.error('chat.getOrCreateTaskRoom', { err: err.message });
    if (err.message === 'Task not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.sendMessage = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const payload = {
      body: req.body.body,
      message_type: req.body.message_type,
      reply_to_id: req.body.reply_to_id ? parseInt(req.body.reply_to_id, 10) : null,
      file: req.file || null
    };
    const message = await ChatService.sendMessage(roomId, req.user, payload, getIo());
    return res.status(201).json({ success: true, data: message });
  } catch (err) {
    logger.error('chat.sendMessage', { err: err.message });
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    if (err.message.includes('required')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.downloadAttachment = async (req, res, next) => {
  try {
    const id = parseInt(req.params.attachmentId, 10);
    const inline = req.query.inline !== 'false';
    await ChatService.streamAttachment(id, req.user, res, { inline });
  } catch (err) {
    logger.error('chat.downloadAttachment', { err: err.message });
    if (err.message === 'Attachment not found' || err.message === 'File missing on disk') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.createGroupRoom = async (req, res, next) => {
  try {
    const room = await ChatService.createGroupRoom(req.user, req.body);
    return res.status(201).json({ success: true, data: room });
  } catch (err) {
    logger.error('chat.createGroupRoom', { err: err.message });
    if (err.message.includes('required') || err.message.includes('at least')) {
      return res.status(400).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.listMembers = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const members = await ChatService.listMembers(roomId, req.user);
    return res.status(200).json({ success: true, data: members });
  } catch (err) {
    logger.error('chat.listMembers', { err: err.message });
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.addMember = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const userId = parseInt(req.body.user_id, 10);
    const member = await ChatService.addMember(roomId, req.user, userId, getIo());
    return res.status(200).json({ success: true, data: member });
  } catch (err) {
    logger.error('chat.addMember', { err: err.message });
    if (err.message === 'Room not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message.includes('Not a member') || err.message.includes('Cannot modify')) {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.removeMember = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const userId = parseInt(req.params.userId, 10);
    await ChatService.removeMember(roomId, req.user, userId, getIo());
    return res.status(200).json({ success: true });
  } catch (err) {
    logger.error('chat.removeMember', { err: err.message });
    if (err.message === 'Room not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message.includes('Cannot modify') || err.message.includes('Only the creator')) {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.markRead = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const result = await ChatService.markRead(roomId, req.user, getIo());
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    logger.error('chat.markRead', { err: err.message });
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.editMessage = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    const result = await ChatService.editMessage(messageId, req.user, req.body.body, getIo());
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    logger.error('chat.editMessage', { err: err.message });
    if (err.message === 'Message not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message.includes('only edit') || err.message === 'Body required') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.deleteMessage = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    await ChatService.deleteMessage(messageId, req.user, getIo());
    return res.status(200).json({ success: true });
  } catch (err) {
    logger.error('chat.deleteMessage', { err: err.message });
    if (err.message === 'Message not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message.includes('only delete')) {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.getUnreadCount = async (req, res, next) => {
  try {
    const count = await ChatService.getUnreadTotal(req.user);
    return res.status(200).json({ success: true, data: { unreadCount: count } });
  } catch (err) {
    logger.error('chat.getUnreadCount', { err: err.message });
    next(err);
  }
};

exports.toggleReaction = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    const { emoji } = req.body;
    const data = await ChatService.toggleReaction(messageId, req.user, emoji, getIo());
    return res.status(200).json({ success: true, data });
  } catch (err) {
    logger.error('chat.toggleReaction', { err: err.message });
    if (err.message === 'Message not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.pinMessage = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    const data = await ChatService.setPinned(messageId, req.user, true, getIo());
    return res.status(200).json({ success: true, data });
  } catch (err) {
    logger.error('chat.pinMessage', { err: err.message });
    if (err.message === 'Message not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.unpinMessage = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    const data = await ChatService.setPinned(messageId, req.user, false, getIo());
    return res.status(200).json({ success: true, data });
  } catch (err) {
    logger.error('chat.unpinMessage', { err: err.message });
    if (err.message === 'Message not found') {
      return res.status(404).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.listPinned = async (req, res, next) => {
  try {
    const roomId = parseInt(req.params.id, 10);
    const data = await ChatService.listPinned(roomId, req.user);
    return res.status(200).json({ success: true, data });
  } catch (err) {
    logger.error('chat.listPinned', { err: err.message });
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.forwardMessage = async (req, res, next) => {
  try {
    const messageId = parseInt(req.params.messageId, 10);
    const targetRoomId = parseInt(req.body.room_id, 10);
    const data = await ChatService.forwardMessage(messageId, req.user, targetRoomId, getIo());
    return res.status(201).json({ success: true, data });
  } catch (err) {
    logger.error('chat.forwardMessage', { err: err.message });
    if (err.message.includes('not found')) {
      return res.status(404).json({ success: false, message: err.message });
    }
    if (err.message === 'Not a member of this room') {
      return res.status(403).json({ success: false, message: err.message });
    }
    next(err);
  }
};

exports.search = async (req, res, next) => {
  try {
    const q = (req.query.q || '').toString();
    const roomId = req.query.room_id ? parseInt(req.query.room_id, 10) : null;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 30;
    const results = await ChatService.search(req.user, { query: q, roomId, limit });
    return res.status(200).json({ success: true, data: results });
  } catch (err) {
    logger.error('chat.search', { err: err.message });
    next(err);
  }
};
