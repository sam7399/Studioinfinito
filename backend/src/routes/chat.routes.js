const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const { authenticate } = require('../middleware/auth');
const upload = require('../config/multer');
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

// Send a message (text only)
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

// Send a message with a file (multipart). Body fields are validated inside controller
// so we don't run celebrate on the form-data body (which would clash with multer).
router.post(
  '/rooms/:id/messages/upload',
  upload.single('file'),
  chatController.sendMessage
);

// Download / inline-view an attachment
router.get(
  '/attachments/:attachmentId',
  celebrate({
    [Segments.PARAMS]: Joi.object({ attachmentId: Joi.number().integer().required() })
  }),
  chatController.downloadAttachment
);

// Group rooms
router.post(
  '/rooms/group',
  celebrate({
    [Segments.BODY]: Joi.object({
      name: Joi.string().required().max(255),
      member_ids: Joi.array().items(Joi.number().integer()).min(1).required()
    })
  }),
  chatController.createGroupRoom
);

router.get(
  '/rooms/:id/members',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() })
  }),
  chatController.listMembers
);

router.post(
  '/rooms/:id/members',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() }),
    [Segments.BODY]: Joi.object({ user_id: Joi.number().integer().required() })
  }),
  chatController.addMember
);

router.delete(
  '/rooms/:id/members/:userId',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required(),
      userId: Joi.number().integer().required()
    })
  }),
  chatController.removeMember
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

// Reactions
router.post(
  '/messages/:messageId/reactions',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() }),
    [Segments.BODY]: Joi.object({ emoji: Joi.string().required().max(16) })
  }),
  chatController.toggleReaction
);

// Pin / unpin
router.post(
  '/messages/:messageId/pin',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() })
  }),
  chatController.pinMessage
);

router.delete(
  '/messages/:messageId/pin',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() })
  }),
  chatController.unpinMessage
);

router.get(
  '/rooms/:id/pinned',
  celebrate({
    [Segments.PARAMS]: Joi.object({ id: Joi.number().integer().required() })
  }),
  chatController.listPinned
);

// Forward
router.post(
  '/messages/:messageId/forward',
  celebrate({
    [Segments.PARAMS]: Joi.object({ messageId: Joi.number().integer().required() }),
    [Segments.BODY]: Joi.object({ room_id: Joi.number().integer().required() })
  }),
  chatController.forwardMessage
);

// Search
router.get(
  '/search',
  celebrate({
    [Segments.QUERY]: Joi.object({
      q: Joi.string().required().min(2).max(255),
      room_id: Joi.number().integer(),
      limit: Joi.number().integer().min(1).max(100)
    })
  }),
  chatController.search
);

module.exports = router;
