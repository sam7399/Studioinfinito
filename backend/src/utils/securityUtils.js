/**
 * Security Utility Functions
 * Helper functions for security-related operations
 */

const crypto = require('crypto');
const validator = require('validator');
const securityConstants = require('../constants/security');

/**
 * Validate password strength
 * @param {string} password - The password to validate
 * @returns {object} - { isValid: boolean, errors: array }
 */
function validatePasswordStrength(password) {
  const errors = [];

  if (!password || password.length < securityConstants.PASSWORD.MIN_LENGTH) {
    errors.push(`Password must be at least ${securityConstants.PASSWORD.MIN_LENGTH} characters long`);
  }

  if ((password.match(/[A-Z]/g) || []).length < securityConstants.PASSWORD.MIN_UPPERCASE) {
    errors.push(`Password must contain at least ${securityConstants.PASSWORD.MIN_UPPERCASE} uppercase letter(s)`);
  }

  if ((password.match(/[a-z]/g) || []).length < securityConstants.PASSWORD.MIN_LOWERCASE) {
    errors.push(`Password must contain at least ${securityConstants.PASSWORD.MIN_LOWERCASE} lowercase letter(s)`);
  }

  if ((password.match(/\d/g) || []).length < securityConstants.PASSWORD.MIN_NUMBERS) {
    errors.push(`Password must contain at least ${securityConstants.PASSWORD.MIN_NUMBERS} number(s)`);
  }

  if (!securityConstants.PASSWORD.SPECIAL_CHARS_REGEX.test(password)) {
    errors.push('Password must contain at least 1 special character (!@#$%^&*()-=_+[]{};\':"|,.<>/?\\)');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Generate a secure random token
 * @param {number} length - Token length in bytes
 * @returns {string} - Hexadecimal token
 */
function generateSecureToken(length = securityConstants.PASSWORD.RESET_TOKEN_LENGTH) {
  return crypto.randomBytes(length).toString('hex');
}

/**
 * Hash a token for storage
 * @param {string} token - The token to hash
 * @returns {string} - SHA256 hash of the token
 */
function hashToken(token) {
  return crypto
    .createHash('sha256')
    .update(token)
    .digest('hex');
}

/**
 * Sanitize input string
 * @param {string} input - The input to sanitize
 * @returns {string} - Sanitized input
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') {
    return input;
  }

  // Escape HTML special characters
  let sanitized = input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');

  // Remove any null bytes
  sanitized = sanitized.replace(/\0/g, '');

  // Trim whitespace
  sanitized = sanitized.trim();

  return sanitized;
}

/**
 * Validate email format
 * @param {string} email - The email to validate
 * @returns {boolean} - True if valid email
 */
function validateEmail(email) {
  if (typeof email !== 'string' || email.length > securityConstants.INPUT.MAX_EMAIL_LENGTH) {
    return false;
  }
  return validator.isEmail(email);
}

/**
 * Validate phone number format
 * @param {string} phone - The phone to validate
 * @returns {boolean} - True if valid phone
 */
function validatePhone(phone) {
  if (typeof phone !== 'string') {
    return false;
  }
  return securityConstants.INPUT.PHONE_PATTERN.test(phone);
}

/**
 * Validate URL format
 * @param {string} url - The URL to validate
 * @returns {boolean} - True if valid URL
 */
function validateURL(url) {
  if (typeof url !== 'string' || url.length > securityConstants.INPUT.MAX_URL_LENGTH) {
    return false;
  }
  return validator.isURL(url);
}

/**
 * Validate date format (YYYY-MM-DD)
 * @param {string} dateString - The date string to validate
 * @returns {boolean} - True if valid date
 */
function validateDateFormat(dateString) {
  if (!dateString || typeof dateString !== 'string') {
    return false;
  }
  return /^\d{4}-\d{2}-\d{2}$/.test(dateString) && !isNaN(new Date(dateString).getTime());
}

/**
 * Sanitize file name
 * @param {string} filename - The filename to sanitize
 * @returns {string} - Sanitized filename
 */
function sanitizeFilename(filename) {
  if (typeof filename !== 'string') {
    return 'file';
  }

  // Remove path separators
  let sanitized = filename.replace(/[\/\\]/g, '');

  // Remove special characters
  sanitized = sanitized.replace(/[^a-zA-Z0-9._-]/g, '');

  // Limit length
  sanitized = sanitized.substring(0, 255);

  return sanitized || 'file';
}

/**
 * Validate file upload
 * @param {object} file - File object from multer
 * @returns {object} - { isValid: boolean, error: string }
 */
function validateFileUpload(file) {
  if (!file) {
    return { isValid: false, error: 'No file provided' };
  }

  // Check file size
  const maxSizeBytes = securityConstants.FILE_UPLOAD.MAX_FILE_SIZE_MB * 1024 * 1024;
  if (file.size > maxSizeBytes) {
    return {
      isValid: false,
      error: `File size exceeds maximum limit of ${securityConstants.FILE_UPLOAD.MAX_FILE_SIZE_MB}MB`
    };
  }

  // Check MIME type
  if (!securityConstants.FILE_UPLOAD.ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return {
      isValid: false,
      error: `File type ${file.mimetype} is not allowed`
    };
  }

  // Check file extension
  const ext = file.originalname.split('.').pop().toLowerCase();
  if (!securityConstants.FILE_UPLOAD.ALLOWED_EXTENSIONS.includes(ext)) {
    return {
      isValid: false,
      error: `File extension .${ext} is not allowed`
    };
  }

  return { isValid: true };
}

/**
 * Generate CSRF token
 * @returns {string} - CSRF token
 */
function generateCSRFToken() {
  return generateSecureToken(32);
}

/**
 * Validate input object against schema
 * @param {object} input - The object to validate
 * @param {object} schema - Validation schema with field configurations
 * @returns {object} - { isValid: boolean, errors: object }
 */
function validateInputObject(input, schema) {
  const errors = {};

  Object.keys(schema).forEach(field => {
    const config = schema[field];
    const value = input[field];

    // Check required fields
    if (config.required && (value === undefined || value === null || value === '')) {
      errors[field] = `${field} is required`;
      return;
    }

    if (value === undefined || value === null || value === '') {
      return;
    }

    // Check type
    if (config.type && typeof value !== config.type) {
      errors[field] = `${field} must be of type ${config.type}`;
      return;
    }

    // Check min length
    if (config.minLength && value.length < config.minLength) {
      errors[field] = `${field} must be at least ${config.minLength} characters`;
      return;
    }

    // Check max length
    if (config.maxLength && value.length > config.maxLength) {
      errors[field] = `${field} must not exceed ${config.maxLength} characters`;
      return;
    }

    // Check pattern
    if (config.pattern && !config.pattern.test(value)) {
      errors[field] = config.patternError || `${field} format is invalid`;
      return;
    }

    // Check custom validator
    if (config.validator && !config.validator(value)) {
      errors[field] = config.validatorError || `${field} validation failed`;
      return;
    }
  });

  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
}

/**
 * Check if string contains SQL injection patterns
 * @param {string} input - The input to check
 * @returns {boolean} - True if potential SQL injection detected
 */
function hasSQLInjectionPattern(input) {
  if (typeof input !== 'string') {
    return false;
  }

  // Common SQL injection patterns
  const sqlPatterns = [
    /(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE)\b)/gi,
    /(-{2}|\/\*|\*\/|xp_|sp_)/i,
    /(;|'|"|`)/,
    /(\{|\})/
  ];

  return sqlPatterns.some(pattern => pattern.test(input));
}

/**
 * Check if string contains XSS patterns
 * @param {string} input - The input to check
 * @returns {boolean} - True if potential XSS detected
 */
function hasXSSPattern(input) {
  if (typeof input !== 'string') {
    return false;
  }

  // Common XSS patterns
  const xssPatterns = [
    /<script[^>]*>[\s\S]*?<\/script>/gi,
    /javascript:/gi,
    /on\w+\s*=/gi,
    /<iframe[^>]*>[\s\S]*?<\/iframe>/gi,
    /<object[^>]*>[\s\S]*?<\/object>/gi,
    /<embed[^>]*>/gi,
    /<img[^>]*>/gi,
    /<svg[^>]*>[\s\S]*?<\/svg>/gi
  ];

  return xssPatterns.some(pattern => pattern.test(input));
}

module.exports = {
  validatePasswordStrength,
  generateSecureToken,
  hashToken,
  sanitizeInput,
  validateEmail,
  validatePhone,
  validateURL,
  validateDateFormat,
  sanitizeFilename,
  validateFileUpload,
  generateCSRFToken,
  validateInputObject,
  hasSQLInjectionPattern,
  hasXSSPattern
};
