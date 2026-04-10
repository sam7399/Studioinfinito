const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const authController = require('../controllers/authController');
const { authLimiter } = require('../middleware/rateLimiter');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Login
router.post(
  '/login',
  authLimiter,
  celebrate({
    [Segments.BODY]: Joi.object({
      email: Joi.string().min(1).required(), // accepts email address OR username
      password: Joi.string().required()
    })
  }),
  authController.login
);

// Forgot password
router.post(
  '/forgot-password',
  authLimiter,
  celebrate({
    [Segments.BODY]: Joi.object({
      email: Joi.string().email().required()
    })
  }),
  authController.forgotPassword
);

// Reset password
router.post(
  '/reset-password',
  authLimiter,
  celebrate({
    [Segments.BODY]: Joi.object({
      token: Joi.string().required(),
      password: Joi.string().min(8).required()
    })
  }),
  authController.resetPassword
);

// Change password (requires authentication)
router.post(
  '/change-password',
  authenticate,
  celebrate({
    [Segments.BODY]: Joi.object({
      current_password: Joi.string().required(),
      new_password: Joi.string().min(8).required()
    })
  }),
  authController.changePassword
);

module.exports = router;