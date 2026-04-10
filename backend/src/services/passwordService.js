/**
 * Password Service
 * Handles password operations: validation, hashing, strength checking
 */

const bcrypt = require('bcrypt');
const securityUtils = require('../utils/securityUtils');
const securityConstants = require('../constants/security');
const logger = require('../utils/logger');

/**
 * Hash a password using bcrypt
 * @param {string} password - Plain text password
 * @returns {Promise<string>} - Hashed password
 */
async function hashPassword(password) {
  try {
    const rounds = securityConstants.PASSWORD.BCRYPT_ROUNDS;
    const hash = await bcrypt.hash(password, rounds);
    return hash;
  } catch (error) {
    logger.error('Password hashing error:', error);
    throw new Error('Failed to hash password');
  }
}

/**
 * Verify a password against its hash
 * @param {string} password - Plain text password
 * @param {string} hash - Password hash
 * @returns {Promise<boolean>} - True if password matches
 */
async function verifyPassword(password, hash) {
  try {
    const match = await bcrypt.compare(password, hash);
    return match;
  } catch (error) {
    logger.error('Password verification error:', error);
    throw new Error('Failed to verify password');
  }
}

/**
 * Validate password strength
 * @param {string} password - Password to validate
 * @returns {object} - Validation result with details
 */
function validatePasswordStrength(password) {
  return securityUtils.validatePasswordStrength(password);
}

/**
 * Check if password should be changed (based on age)
 * Passwords older than 90 days should be changed
 * @param {Date} lastChangedAt - Date password was last changed
 * @param {number} daysThreshold - Days threshold (default 90)
 * @returns {boolean} - True if password should be changed
 */
function shouldChangePassword(lastChangedAt, daysThreshold = 90) {
  if (!lastChangedAt) {
    return true; // Force change if no date found
  }

  const now = Date.now();
  const daysSinceChange = (now - new Date(lastChangedAt).getTime()) / (1000 * 60 * 60 * 24);
  
  return daysSinceChange > daysThreshold;
}

/**
 * Check if password change is overdue
 * @param {Date} lastChangedAt - Date password was last changed
 * @param {number} daysThreshold - Days before overdue (default 90)
 * @returns {object} - Status with days remaining/overdue
 */
function checkPasswordStatus(lastChangedAt, daysThreshold = 90) {
  const now = Date.now();
  const changeDate = new Date(lastChangedAt);
  const daysPerMs = 1000 * 60 * 60 * 24;
  const daysSinceChange = (now - changeDate.getTime()) / daysPerMs;
  const daysRemaining = Math.max(0, daysThreshold - daysSinceChange);

  return {
    daysSinceChange: Math.floor(daysSinceChange),
    daysRemaining: Math.floor(daysRemaining),
    isOverdue: daysRemaining <= 0,
    expiresAt: new Date(changeDate.getTime() + (daysThreshold * daysPerMs))
  };
}

/**
 * Generate password reset token
 * @returns {object} - Token and its hash
 */
function generatePasswordResetToken() {
  const token = securityUtils.generateSecureToken();
  const hash = securityUtils.hashToken(token);

  return {
    token,      // Return to user (send via email)
    hash,       // Store in database
    expiresAt: new Date(Date.now() + securityConstants.PASSWORD.RESET_TOKEN_EXPIRY_HOURS * 60 * 60 * 1000)
  };
}

/**
 * Verify password reset token
 * @param {string} token - Token to verify
 * @param {string} storedHash - Stored hash from database
 * @param {Date} expiresAt - Token expiration date
 * @returns {object} - Verification result
 */
function verifyPasswordResetToken(token, storedHash, expiresAt) {
  // Check expiration
  if (new Date() > new Date(expiresAt)) {
    return {
      isValid: false,
      error: 'Token has expired',
      expired: true
    };
  }

  // Verify token hash
  const tokenHash = securityUtils.hashToken(token);
  if (tokenHash !== storedHash) {
    return {
      isValid: false,
      error: 'Invalid token',
      expired: false
    };
  }

  return {
    isValid: true,
    expiresAt
  };
}

/**
 * Check if two passwords are the same (prevent reuse)
 * @param {string} newPassword - New password
 * @param {string} oldPasswordHash - Old password hash
 * @returns {Promise<boolean>} - True if passwords are the same
 */
async function isSamePassword(newPassword, oldPasswordHash) {
  try {
    return await verifyPassword(newPassword, oldPasswordHash);
  } catch (error) {
    logger.error('Password comparison error:', error);
    return false;
  }
}

/**
 * Get password strength requirement message
 * @returns {string} - Human-readable requirements
 */
function getPasswordRequirements() {
  const pw = securityConstants.PASSWORD;
  return `Password must contain:
    - At least ${pw.MIN_LENGTH} characters
    - At least ${pw.MIN_UPPERCASE} uppercase letter(s)
    - At least ${pw.MIN_LOWERCASE} lowercase letter(s)
    - At least ${pw.MIN_NUMBERS} number(s)
    - At least ${pw.MIN_SPECIAL_CHARS} special character(s) (!@#$%^&*()-=_+[]{};\':"|,.<>/?\\)`;
}

/**
 * Validate password during user registration
 * @param {string} password - Password to validate
 * @param {string} passwordConfirm - Confirmation password
 * @returns {object} - Validation result
 */
function validatePasswordRegistration(password, passwordConfirm) {
  // Check if passwords match
  if (password !== passwordConfirm) {
    return {
      isValid: false,
      errors: ['Passwords do not match']
    };
  }

  // Check strength
  return validatePasswordStrength(password);
}

/**
 * Validate password during change
 * @param {string} currentPassword - Current password
 * @param {string} newPassword - New password
 * @param {string} confirmPassword - Confirmation password
 * @param {string} currentPasswordHash - Hash of current password
 * @returns {Promise<object>} - Validation result
 */
async function validatePasswordChange(currentPassword, newPassword, confirmPassword, currentPasswordHash) {
  // Verify current password
  const currentValid = await verifyPassword(currentPassword, currentPasswordHash);
  if (!currentValid) {
    return {
      isValid: false,
      errors: ['Current password is incorrect']
    };
  }

  // Check if new password is same as current
  const sameAsOld = await isSamePassword(newPassword, currentPasswordHash);
  if (sameAsOld) {
    return {
      isValid: false,
      errors: ['New password must be different from current password']
    };
  }

  // Check if passwords match
  if (newPassword !== confirmPassword) {
    return {
      isValid: false,
      errors: ['New passwords do not match']
    };
  }

  // Check strength
  return validatePasswordStrength(newPassword);
}

module.exports = {
  hashPassword,
  verifyPassword,
  validatePasswordStrength,
  shouldChangePassword,
  checkPasswordStatus,
  generatePasswordResetToken,
  verifyPasswordResetToken,
  isSamePassword,
  getPasswordRequirements,
  validatePasswordRegistration,
  validatePasswordChange
};
