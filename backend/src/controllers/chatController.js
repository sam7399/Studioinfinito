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
    const message = await ChatService.sendMessage(roomId, req.user, req.body, getIo());
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
