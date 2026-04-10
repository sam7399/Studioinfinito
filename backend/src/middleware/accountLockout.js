/**
 * Account Lockout Middleware
 * Implements account lockout after failed login attempts
 */

const securityConstants = require('../constants/security');
const logger = require('../utils/logger');

// Store failed login attempts
// Format: { email: { attempts: number, lastAttemptTime: timestamp, lockedUntil: timestamp } }
const loginAttempts = new Map();

/**
 * Get lockout status for an email
 * @param {string} email - The email address
 * @returns {object} - Lockout status information
 */
function getLockoutStatus(email) {
  const emailLower = email.toLowerCase();
  const attemptData = loginAttempts.get(emailLower);

  if (!attemptData) {
    return {
      isLocked: false,
      attempts: 0,
      remaining: securityConstants.ACCOUNT_LOCKOUT.MAX_LOGIN_ATTEMPTS
    };
  }

  const now = Date.now();
  const isLocked = attemptData.lockedUntil && now < attemptData.lockedUntil;

  if (isLocked) {
    const remainingMs = attemptData.lockedUntil - now;
    return {
      isLocked: true,
      attempts: attemptData.attempts,
      lockedUntil: new Date(attemptData.lockedUntil),
      remainingMinutes: Math.ceil(remainingMs / (60 * 1000))
    };
  }

  // Check if reset time has passed
  const resetTimeMs = securityConstants.ACCOUNT_LOCKOUT.RESET_AFTER_MINUTES * 60 * 1000;
  if (now - attemptData.lastAttemptTime > resetTimeMs) {
    loginAttempts.delete(emailLower);
    return {
      isLocked: false,
      attempts: 0,
      remaining: securityConstants.ACCOUNT_LOCKOUT.MAX_LOGIN_ATTEMPTS
    };
  }

  return {
    isLocked: false,
    attempts: attemptData.attempts,
    remaining: Math.max(0, securityConstants.ACCOUNT_LOCKOUT.MAX_LOGIN_ATTEMPTS - attemptData.attempts)
  };
}

/**
 * Record failed login attempt
 * @param {string} email - The email address
 */
function recordFailedLoginAttempt(email) {
  const emailLower = email.toLowerCase();
  const attemptData = loginAttempts.get(emailLower) || {
    attempts: 0,
    firstAttemptTime: Date.now(),
    lastAttemptTime: Date.now()
  };

  attemptData.attempts += 1;
  attemptData.lastAttemptTime = Date.now();

  // Lock account if max attempts reached
  if (attemptData.attempts >= securityConstants.ACCOUNT_LOCKOUT.MAX_LOGIN_ATTEMPTS) {
    const lockoutDurationMs = securityConstants.ACCOUNT_LOCKOUT.LOCKOUT_DURATION_MINUTES * 60 * 1000;
    attemptData.lockedUntil = Date.now() + lockoutDurationMs;

    logger.warn('Account locked due to failed login attempts', {
      email: emailLower,
      attempts: attemptData.attempts,
      lockedUntil: new Date(attemptData.lockedUntil)
    });
  }

  loginAttempts.set(emailLower, attemptData);

  logger.debug('Failed login attempt recorded', {
    email: emailLower,
    attempts: attemptData.attempts,
    locked: !!attemptData.lockedUntil
  });
}

/**
 * Clear failed login attempts for an email (on successful login)
 * @param {string} email - The email address
 */
function clearFailedLoginAttempts(email) {
  const emailLower = email.toLowerCase();
  loginAttempts.delete(emailLower);

  logger.debug('Failed login attempts cleared', { email: emailLower });
}

/**
 * Middleware to check account lockout status
 * Use before authentication attempt
 */
function checkAccountLockout(req, res, next) {
  try {
    const email = req.body.email;

    if (!email) {
      return next();
    }

    const lockoutStatus = getLockoutStatus(email);

    if (lockoutStatus.isLocked) {
      logger.warn(`Login attempt on locked account: ${email.toLowerCase()}`, {
        ip: req.ip,
        lockedUntil: lockoutStatus.lockedUntil
      });

      return res.status(429).json({
        success: false,
        message: securityConstants.ERROR_MESSAGES.ACCOUNT_LOCKED,
        lockoutUntil: lockoutStatus.lockedUntil.toISOString(),
        remainingMinutes: lockoutStatus.remainingMinutes
      });
    }

    // Add lockout status to request for later use
    req.lockoutStatus = lockoutStatus;
    next();
  } catch (error) {
    logger.error('Account lockout check error:', error);
    next();
  }
}

/**
 * Middleware to handle failed login
 * Use after failed authentication attempt
 */
function handleFailedLogin(req, res, next) {
  const email = req.body.email;

  if (email) {
    recordFailedLoginAttempt(email);
  }

  next();
}

/**
 * Middleware to handle successful login
 * Use after successful authentication
 */
function handleSuccessfulLogin(req, res, next) {
  const email = req.user?.email || req.body?.email;

  if (email) {
    clearFailedLoginAttempts(email);
  }

  next();
}

/**
 * Cleanup expired lockouts periodically
 * Lockouts older than their duration are removed
 */
function cleanupExpiredLockouts() {
  const now = Date.now();

  for (const [email, data] of loginAttempts.entries()) {
    // Remove if lockout has expired
    if (data.lockedUntil && now >= data.lockedUntil) {
      // Reset attempts after lockout expires
      data.attempts = 0;
      data.lockedUntil = null;
    }

    // Remove if no attempts for longer than reset time
    const resetTimeMs = securityConstants.ACCOUNT_LOCKOUT.RESET_AFTER_MINUTES * 60 * 1000;
    if (now - data.lastAttemptTime > resetTimeMs) {
      loginAttempts.delete(email);
    }
  }
}

/**
 * Start automatic lockout cleanup
 * Runs every 5 minutes
 */
function startLockoutCleanup() {
  setInterval(() => {
    cleanupExpiredLockouts();
    logger.debug('Account lockout cleanup completed', {
      lockedAccounts: loginAttempts.size
    });
  }, 5 * 60 * 1000); // 5 minutes
}

/**
 * Get all locked accounts (for admin purposes)
 * @returns {array} - Array of locked accounts with status
 */
function getLockedAccounts() {
  const now = Date.now();
  const locked = [];

  for (const [email, data] of loginAttempts.entries()) {
    if (data.lockedUntil && now < data.lockedUntil) {
      locked.push({
        email,
        attempts: data.attempts,
        lockedUntil: new Date(data.lockedUntil),
        remainingMinutes: Math.ceil((data.lockedUntil - now) / (60 * 1000))
      });
    }
  }

  return locked;
}

/**
 * Manually unlock an account (for admin purposes)
 * @param {string} email - The email address to unlock
 * @returns {boolean} - True if account was locked and is now unlocked
 */
function unlockAccount(email) {
  const emailLower = email.toLowerCase();
  const wasLocked = loginAttempts.has(emailLower);

  if (wasLocked) {
    loginAttempts.delete(emailLower);
    logger.info('Account manually unlocked', { email: emailLower });
  }

  return wasLocked;
}

module.exports = {
  getLockoutStatus,
  recordFailedLoginAttempt,
  clearFailedLoginAttempts,
  checkAccountLockout,
  handleFailedLogin,
  handleSuccessfulLogin,
  startLockoutCleanup,
  cleanupExpiredLockouts,
  getLockedAccounts,
  unlockAccount
};
