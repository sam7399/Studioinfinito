const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const { authenticate } = require('../middleware/auth');
const chatController = require('../controllers/chatController');

const router = express.Router();

router.use(authenticate);

// List user's rooms (left pane)
router.get('/rooms', chatController.listRooms);

// Total unread count (badge)
router.get('/unread-count', chatController.getUnreadCount);

// Create / get a 1-1 direct room
router.post(
  '/rooms/direct',
  celebrate({
    [Segments.BODY]: Joi.object({
      user_id: Joi.number().integer().required()
    })
  }),
  chatController.createDirectRoom
);

// Get / create a task-scoped room
router.post(
  '/rooms/task/:taskId',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      taskId: Joi.number().integer().required()
    })
  }),
  chatController.getOrCreateTaskRoom
);

// Get messages in a room
router.get(
  '/rooms/:id/messages',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() }),
    [Segments.QUERY]: Joi.object({
      limit: Joi.number().integer().min(1).max(100),
      before_id: Joi.number().integer()
    })
  }),
  chatController.getMessages
);

// Send a message
router.post(
  '/rooms/:id/messages',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() }),
    [Segments.BODY]: Joi.object({
      body: Joi.string().required().max(4000),
      message_type: Joi.string().valid('text', 'image', 'file').default('text'),
      reply_to_id: Joi.number().integer().allow(null)
    })
  }),
  chatController.sendMessage
);

// Mark room as read
router.post(
  '/rooms/:id/read',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() })
  }),
  chatController.markRead
);

// Edit a message
router.patch(
  '/messages/:messageId',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() }),
    [Segments.BODY]: Joi.object({ body: Joi.string().required().max(4000) })
  }),
  chatController.editMessage
);

// Delete (soft) a message
router.delete(
  '/messages/:messageId',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() })
  }),
  chatController.deleteMessage
);

module.exports = router;
