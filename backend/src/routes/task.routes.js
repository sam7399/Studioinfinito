const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const taskController = require('../controllers/taskController');
const { authenticate, requireRole } = require('../middleware/auth');
const upload = require('../config/multer');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

// List tasks
router.get(
  '/',
  celebrate({
    [Segments.QUERY]: Joi.object({
      page: Joi.number().integer().min(1).default(1),
      limit: Joi.number().integer().min(1).max(100).default(20),
      status: Joi.string().valid('open', 'in_progress', 'complete_pending_review', 'finalized', 'reopened'),
      priority: Joi.string().valid('low', 'normal', 'high', 'urgent'),
      assigned_to: Joi.number().integer(),
      created_by: Joi.number().integer(),
      department_id: Joi.number().integer(),
      location_id: Joi.number().integer(),
      due_date_from: Joi.date().iso(),
      due_date_to: Joi.date().iso(),
      search: Joi.string(),
      sort_by: Joi.string().valid('created_at', 'updated_at', 'due_date', 'priority', 'status', 'title'),
      sort_order: Joi.string().valid('asc', 'desc').default('desc')
    })
  }),
  taskController.listTasks
);

// Get task by ID
router.get(
  '/:id',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  taskController.getTask
);

// Create task — all authenticated users can create tasks
router.post(
  '/',
  celebrate({
    [Segments.BODY]: Joi.object({
      title: Joi.string().required().max(255),
      description: Joi.string().allow(''),
      priority: Joi.string().valid('low', 'normal', 'high', 'urgent').default('normal'),
      status: Joi.string().valid('open', 'in_progress', 'complete_pending_review', 'finalized', 'reopened').default('open'),
      assigned_to: Joi.number().integer().required(),
      assigned_to_ids: Joi.array().items(Joi.number().integer()).default([]),
      show_collaborators: Joi.boolean().default(true),
      depends_on_task_id: Joi.number().integer().allow(null),
      department_id: Joi.number().integer().required(),
      location_id: Joi.number().integer().required(),
      due_date: Joi.date().iso().required(),
      estimated_hours: Joi.number().min(0).allow(null),
      tags: Joi.array().items(Joi.string()).default([])
    })
  }),
  taskController.createTask
);

// Get workload summary for a user (for popup before assigning)
router.get(
  '/workload/:userId',
  celebrate({
    [Segments.PARAMS]: Joi.object({ userId: Joi.number().integer().required() })
  }),
  taskController.getUserWorkloadSummary
);

// Update task
router.put(
  '/:id',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      title: Joi.string().max(255),
      description: Joi.string().allow(''),
      priority: Joi.string().valid('low', 'normal', 'high', 'urgent'),
      status: Joi.string().valid('open', 'in_progress', 'complete_pending_review', 'finalized', 'reopened'),
      assigned_to: Joi.number().integer(),
      department_id: Joi.number().integer(),
      location_id: Joi.number().integer(),
      due_date: Joi.date().iso(),
      estimated_hours: Joi.number().min(0).allow(null),
      actual_hours: Joi.number().min(0).allow(null),
      tags: Joi.array().items(Joi.string())
    })
  }),
  taskController.updateTask
);

// Delete task
router.delete(
  '/:id',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  taskController.deleteTask
);

// Get task activities
router.get(
  '/:id/activities',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  taskController.getTaskActivities
);

// Complete task (mark as complete_pending_review)
router.post(
  '/:id/complete',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  taskController.completeTask
);

// Reopen task (only task creator/assigner can reopen)
router.post(
  '/:id/reopen',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      comment: Joi.string().required().min(1).max(1000)
        .messages({ 'any.required': 'A comment is required when reopening a task' })
    })
  }),
  taskController.reopenTask
);

// Submit task review
router.post(
  '/:id/review',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      rating: Joi.number().integer().min(1).max(5).required(),
      comments: Joi.string().allow(''),
      quality_score: Joi.number().integer().min(1).max(5),
      timeliness_score: Joi.number().integer().min(1).max(5)
    })
  }),
  taskController.submitReview
);

// Get task statistics (all authenticated users — service applies visibility scope)
router.get(
  '/stats/overview',
  celebrate({
    [Segments.QUERY]: Joi.object({
      start_date: Joi.date().iso(),
      end_date: Joi.date().iso(),
      department_id: Joi.number().integer(),
      location_id: Joi.number().integer()
    })
  }),
  taskController.getStatistics
);

// Bulk assign tasks to multiple users
router.post(
  '/bulk-assign',
  requireRole('superadmin', 'management', 'department_head', 'manager'),
  celebrate({
    [Segments.BODY]: Joi.object({
      task_ids: Joi.array().items(Joi.number().integer()).min(1).required(),
      user_ids: Joi.array().items(Joi.number().integer()).min(1).required()
    })
  }),
  taskController.bulkAssign
);

// Bulk create multiple new tasks — all authenticated users
router.post(
  '/bulk-create',
  celebrate({
    [Segments.BODY]: Joi.object({
      tasks: Joi.array().items(
        Joi.object({
          title: Joi.string().required().max(255),
          description: Joi.string().allow('').default(''),
          priority: Joi.string().valid('low', 'normal', 'high', 'urgent').default('high'),
          assigned_to: Joi.number().integer().required(),
          department_id: Joi.number().integer().allow(null),
          location_id: Joi.number().integer().required(),
          due_date: Joi.date().iso().required(),
          estimated_hours: Joi.number().min(0).allow(null),
          depends_on_task_id: Joi.number().integer().allow(null),
          tags: Joi.array().items(Joi.string()).default([])
        })
      ).min(1).required()
    })
  }),
  taskController.bulkCreate
);

// Attachment routes
router.post('/:id/attachments', upload.single('file'), taskController.uploadAttachment);
router.get('/:id/attachments', taskController.getAttachments);
router.get('/:id/attachments/:attachmentId/download', taskController.downloadAttachment);
router.delete('/:id/attachments/:attachmentId', taskController.deleteAttachment);

module.exports = router;