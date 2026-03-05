const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const userController = require('../controllers/userController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

// Get user workload
router.get(
  '/:id/workload',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.QUERY]: Joi.object({
      start_date: Joi.date().iso(),
      end_date: Joi.date().iso()
    })
  }),
  userController.getWorkload
);

// Get user performance
router.get(
  '/:id/performance',
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.QUERY]: Joi.object({
      start_date: Joi.date().iso(),
      end_date: Joi.date().iso()
    })
  }),
  userController.getPerformance
);

// List users (management and superadmin only)
router.get(
  '/',
  requireRole('superadmin', 'management'),
  celebrate({
    [Segments.QUERY]: Joi.object({
      page: Joi.number().integer().min(1).default(1),
      limit: Joi.number().integer().min(1).max(500).default(20),
      role: Joi.string().valid('superadmin', 'management', 'employee'),
      department_id: Joi.number().integer(),
      location_id: Joi.number().integer(),
      is_active: Joi.boolean(),
      search: Joi.string()
    })
  }),
  userController.listUsers
);

// Get user by ID (management and superadmin only)
router.get(
  '/:id',
  requireRole('superadmin', 'management'),
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  userController.getUser
);

// Create user (management and superadmin only)
router.post(
  '/',
  requireRole('superadmin', 'management'),
  celebrate({
    [Segments.BODY]: Joi.object({
      email: Joi.string().email().required(),
      password: Joi.string().min(8).required(),
      name: Joi.string().max(255),
      first_name: Joi.string().max(100),
      last_name: Joi.string().max(100),
      role: Joi.string().valid('superadmin', 'management', 'department_head', 'manager', 'employee').required(),
      department_id: Joi.number().integer().required(),
      location_id: Joi.number().integer().required(),
      phone: Joi.string().max(20).allow(null, ''),
      emp_code: Joi.string().max(50).allow(null, ''),
      username: Joi.string().max(100).allow(null, ''),
      designation: Joi.string().max(100).allow(null, ''),
      date_of_birth: Joi.date().iso().allow(null),
      manager_id: Joi.number().integer().allow(null),
      department_head_id: Joi.number().integer().allow(null),
      is_active: Joi.boolean().default(true)
    })
  }),
  userController.createUser
);

// Update user (management and superadmin only)
router.put(
  '/:id',
  requireRole('superadmin', 'management'),
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    }),
    [Segments.BODY]: Joi.object({
      email: Joi.string().email(),
      name: Joi.string().max(255),
      first_name: Joi.string().max(100),
      last_name: Joi.string().max(100),
      role: Joi.string().valid('superadmin', 'management', 'department_head', 'manager', 'employee'),
      department_id: Joi.number().integer(),
      location_id: Joi.number().integer(),
      phone: Joi.string().max(20).allow(null, ''),
      emp_code: Joi.string().max(50).allow(null, ''),
      username: Joi.string().max(100).allow(null, ''),
      designation: Joi.string().max(100).allow(null, ''),
      date_of_birth: Joi.date().iso().allow(null),
      manager_id: Joi.number().integer().allow(null),
      department_head_id: Joi.number().integer().allow(null),
      is_active: Joi.boolean()
    })
  }),
  userController.updateUser
);

// Delete user (superadmin only)
router.delete(
  '/:id',
  requireRole('superadmin'),
  celebrate({
    [Segments.PARAMS]: Joi.object({
      id: Joi.number().integer().required()
    })
  }),
  userController.deleteUser
);

module.exports = router;