/**
 * Request Validation & Sanitization Middleware
 * Validates and sanitizes all incoming request data
 */

const { body, param, query, validationResult } = require('express-validator');
const securityUtils = require('../utils/securityUtils');
const securityConstants = require('../constants/security');
const logger = require('../utils/logger');

/**
 * Middleware to handle validation errors
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    logger.warn('Validation error', {
      path: req.path,
      errors: errors.array(),
      ip: req.ip
    });

    return res.status(400).json({
      success: false,
      message: securityConstants.ERROR_MESSAGES.VALIDATION_ERROR,
      errors: errors.array().map(err => ({
        field: err.param,
        message: err.msg,
        value: err.value
      }))
    });
  }

  next();
};

/**
 * Sanitize request body
 */
const sanitizeRequestBody = (req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    Object.keys(req.body).forEach(key => {
      if (typeof req.body[key] === 'string') {
        // Check for SQL injection patterns
        if (securityUtils.hasSQLInjectionPattern(req.body[key])) {
          logger.warn('Potential SQL injection detected', {
            field: key,
            path: req.path,
            ip: req.ip
          });
          return res.status(400).json({
            success: false,
            message: securityConstants.ERROR_MESSAGES.VALIDATION_ERROR
          });
        }

        // Check for XSS patterns
        if (securityUtils.hasXSSPattern(req.body[key])) {
          logger.warn('Potential XSS detected', {
            field: key,
            path: req.path,
            ip: req.ip
          });
          return res.status(400).json({
            success: false,
            message: securityConstants.ERROR_MESSAGES.VALIDATION_ERROR
          });
        }

        // Sanitize string
        req.body[key] = securityUtils.sanitizeInput(req.body[key]);
      }
    });
  }

  next();
};

/**
 * Validate email field
 */
const validateEmailField = (fieldName = 'email') => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isEmail()
    .withMessage(`${fieldName} must be a valid email address`)
    .normalizeEmail()
    .custom((value) => {
      if (value.length > securityConstants.INPUT.MAX_EMAIL_LENGTH) {
        throw new Error(`${fieldName} must not exceed ${securityConstants.INPUT.MAX_EMAIL_LENGTH} characters`);
      }
      return true;
    });
};

/**
 * Validate password field
 */
const validatePasswordField = (fieldName = 'password', checkStrength = true) => {
  let validation = body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isLength({ min: securityConstants.PASSWORD.MIN_LENGTH })
    .withMessage(`${fieldName} must be at least ${securityConstants.PASSWORD.MIN_LENGTH} characters`);

  if (checkStrength) {
    validation = validation.custom((value) => {
      const result = securityUtils.validatePasswordStrength(value);
      if (!result.isValid) {
        throw new Error(result.errors.join('; '));
      }
      return true;
    });
  }

  return validation;
};

/**
 * Validate username field
 */
const validateUsernameField = (fieldName = 'username') => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isLength({ min: 3, max: 20 })
    .withMessage(`${fieldName} must be between 3 and 20 characters`)
    .matches(securityConstants.INPUT.USERNAME_PATTERN)
    .withMessage(`${fieldName} can only contain letters, numbers, dots, hyphens, and underscores`);
};

/**
 * Validate phone field
 */
const validatePhoneField = (fieldName = 'phone') => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .custom((value) => {
      if (!securityUtils.validatePhone(value)) {
        throw new Error(`${fieldName} format is invalid`);
      }
      return true;
    });
};

/**
 * Validate date field (YYYY-MM-DD)
 */
const validateDateField = (fieldName = 'date') => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .custom((value) => {
      if (!securityUtils.validateDateFormat(value)) {
        throw new Error(`${fieldName} must be in YYYY-MM-DD format`);
      }
      return true;
    });
};

/**
 * Validate URL field
 */
const validateURLField = (fieldName = 'url') => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .custom((value) => {
      if (!securityUtils.validateURL(value)) {
        throw new Error(`${fieldName} must be a valid URL`);
      }
      return true;
    });
};

/**
 * Validate string field with length constraints
 */
const validateStringField = (fieldName, minLength = 1, maxLength = securityConstants.INPUT.MAX_STRING_LENGTH) => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isLength({ min: minLength, max: maxLength })
    .withMessage(`${fieldName} must be between ${minLength} and ${maxLength} characters`);
};

/**
 * Validate numeric field
 */
const validateNumericField = (fieldName, min = 0, max = null) => {
  let validation = body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isNumeric()
    .withMessage(`${fieldName} must be a number`)
    .custom((value) => {
      const num = parseFloat(value);
      if (num < min) {
        throw new Error(`${fieldName} must be greater than or equal to ${min}`);
      }
      if (max && num > max) {
        throw new Error(`${fieldName} must be less than or equal to ${max}`);
      }
      return true;
    });

  return validation;
};

/**
 * Validate array field
 */
const validateArrayField = (fieldName, minItems = 1, maxItems = 100) => {
  return body(fieldName)
    .isArray({ min: minItems, max: maxItems })
    .withMessage(`${fieldName} must be an array with between ${minItems} and ${maxItems} items`);
};

/**
 * Validate enum field
 */
const validateEnumField = (fieldName, allowedValues) => {
  return body(fieldName)
    .trim()
    .notEmpty()
    .withMessage(`${fieldName} is required`)
    .isIn(allowedValues)
    .withMessage(`${fieldName} must be one of: ${allowedValues.join(', ')}`);
};

/**
 * Validate ID parameter (positive integer)
 */
const validateIdParam = (paramName = 'id') => {
  return param(paramName)
    .trim()
    .notEmpty()
    .withMessage(`${paramName} is required`)
    .isInt({ min: 1 })
    .withMessage(`${paramName} must be a positive integer`);
};

/**
 * Validate UUID parameter
 */
const validateUUIDParam = (paramName = 'id') => {
  return param(paramName)
    .trim()
    .notEmpty()
    .withMessage(`${paramName} is required`)
    .isUUID()
    .withMessage(`${paramName} must be a valid UUID`);
};

/**
 * Validate search query parameter
 */
const validateSearchQuery = (fieldName = 'q', minLength = 1, maxLength = 100) => {
  return query(fieldName)
    .optional()
    .trim()
    .isLength({ min: minLength, max: maxLength })
    .withMessage(`${fieldName} must be between ${minLength} and ${maxLength} characters`);
};

/**
 * Validate pagination parameters
 */
const validatePaginationParams = (req, res, next) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;

  // Validate page
  if (page < 1) {
    return res.status(400).json({
      success: false,
      message: 'Page must be greater than 0'
    });
  }

  // Validate limit
  if (limit < 1 || limit > 100) {
    return res.status(400).json({
      success: false,
      message: 'Limit must be between 1 and 100'
    });
  }

  req.pagination = { page, limit };
  next();
};

/**
 * Validate file upload in request
 */
const validateFileInRequest = (req, res, next) => {
  if (!req.file) {
    return res.status(400).json({
      success: false,
      message: 'No file uploaded'
    });
  }

  const validation = securityUtils.validateFileUpload(req.file);
  if (!validation.isValid) {
    return res.status(400).json({
      success: false,
      message: validation.error
    });
  }

  next();
};

/**
 * Validate multiple files upload
 */
const validateFilesInRequest = (req, res, next) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'No files uploaded'
    });
  }

  for (const file of req.files) {
    const validation = securityUtils.validateFileUpload(file);
    if (!validation.isValid) {
      return res.status(400).json({
        success: false,
        message: validation.error
      });
    }
  }

  next();
};

module.exports = {
  handleValidationErrors,
  sanitizeRequestBody,
  validateEmailField,
  validatePasswordField,
  validateUsernameField,
  validatePhoneField,
  validateDateField,
  validateURLField,
  validateStringField,
  validateNumericField,
  validateArrayField,
  validateEnumField,
  validateIdParam,
  validateUUIDParam,
  validateSearchQuery,
  validatePaginationParams,
  validateFileInRequest,
  validateFilesInRequest
};
