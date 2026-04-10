/**
 * CSRF Protection Middleware
 * Implements CSRF token generation, validation, and management
 */

const securityUtils = require('../utils/securityUtils');
const securityConstants = require('../constants/security');
const logger = require('../utils/logger');

// Store for CSRF tokens (in production, use Redis or database)
// Format: { token: { createdAt, userId, isValid } }
const csrfTokenStore = new Map();

/**
 * Generate and return CSRF token
 * Creates a new token and stores it
 */
function generateCSRFToken(req, res, next) {
  try {
    const token = securityUtils.generateCSRFToken();
    const tokenData = {
      createdAt: Date.now(),
      userId: req.user ? req.user.id : null,
      isValid: true
    };

    csrfTokenStore.set(token, tokenData);

    // Set token in response headers and body
    res.set('X-CSRF-Token', token);
    res.csrfToken = token;

    next();
  } catch (error) {
    logger.error('CSRF token generation error:', error);
    res.status(500).json({
      success: false,
      message: securityConstants.ERROR_MESSAGES.SERVER_ERROR
    });
  }
}

/**
 * Validate CSRF token
 * Checks token validity and marks it as used
 */
function validateCSRFToken(req, res, next) {
  try {
    // Get token from headers or body
    const token = req.headers['x-csrf-token'] || 
                  req.body._csrf || 
                  req.query.csrf;

    if (!token) {
      logger.warn(`Missing CSRF token for ${req.method} ${req.path}`, {
        ip: req.ip,
        userId: req.user ? req.user.id : null
      });
      return res.status(403).json({
        success: false,
        message: 'CSRF token is missing'
      });
    }

    // Check if token exists and is valid
    const tokenData = csrfTokenStore.get(token);

    if (!tokenData || !tokenData.isValid) {
      logger.warn(`Invalid CSRF token for ${req.method} ${req.path}`, {
        ip: req.ip,
        userId: req.user ? req.user.id : null
      });
      return res.status(403).json({
        success: false,
        message: 'Invalid CSRF token'
      });
    }

    // Mark token as used
    tokenData.isValid = false;
    tokenData.usedAt = Date.now();

    logger.debug('CSRF token validated', { userId: req.user ? req.user.id : null });
    next();
  } catch (error) {
    logger.error('CSRF token validation error:', error);
    res.status(500).json({
      success: false,
      message: securityConstants.ERROR_MESSAGES.SERVER_ERROR
    });
  }
}

/**
 * Skip CSRF validation for specific routes
 * Safe methods (GET, HEAD, OPTIONS) and public endpoints don't need CSRF
 */
function skipCSRFForSafeMethods(req, res, next) {
  // Skip CSRF for safe HTTP methods
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }

  // Skip CSRF for public endpoints (you can customize this list)
  const publicEndpoints = [
    '/api/v1/auth/login',
    '/api/v1/auth/register',
    '/api/v1/auth/forgot-password'
  ];

  if (publicEndpoints.includes(req.path)) {
    return next();
  }

  // Validate CSRF for state-changing operations
  validateCSRFToken(req, res, next);
}

/**
 * Middleware to provide CSRF token in GET requests
 * Add token to response for forms
 */
function provideCSRFToken(req, res, next) {
  const token = securityUtils.generateCSRFToken();
  const tokenData = {
    createdAt: Date.now(),
    userId: req.user ? req.user.id : null,
    isValid: true
  };

  csrfTokenStore.set(token, tokenData);

  // Add token to response
  res.csrfToken = token;
  res.set('X-CSRF-Token', token);

  next();
}

/**
 * Cleanup expired CSRF tokens periodically
 * Tokens older than 24 hours are removed
 */
function cleanupExpiredTokens() {
  const tokenExpiry = 24 * 60 * 60 * 1000; // 24 hours
  const now = Date.now();

  for (const [token, data] of csrfTokenStore.entries()) {
    if (now - data.createdAt > tokenExpiry) {
      csrfTokenStore.delete(token);
    }
  }
}

/**
 * Start automatic token cleanup
 * Runs every hour
 */
function startTokenCleanup() {
  setInterval(() => {
    cleanupExpiredTokens();
    logger.debug('CSRF token cleanup completed', {
      tokensRemaining: csrfTokenStore.size
    });
  }, 60 * 60 * 1000); // 1 hour
}

/**
 * Get CSRF token for client use
 * Returns token in response JSON
 */
function getCSRFTokenEndpoint(req, res) {
  try {
    const token = securityUtils.generateCSRFToken();
    const tokenData = {
      createdAt: Date.now(),
      userId: req.user ? req.user.id : null,
      isValid: true
    };

    csrfTokenStore.set(token, tokenData);

    res.json({
      success: true,
      csrfToken: token,
      expiresAt: new Date(tokenData.createdAt + 24 * 60 * 60 * 1000).toISOString()
    });
  } catch (error) {
    logger.error('Error getting CSRF token:', error);
    res.status(500).json({
      success: false,
      message: securityConstants.ERROR_MESSAGES.SERVER_ERROR
    });
  }
}

module.exports = {
  generateCSRFToken,
  validateCSRFToken,
  skipCSRFForSafeMethods,
  provideCSRFToken,
  startTokenCleanup,
  getCSRFTokenEndpoint,
  cleanupExpiredTokens
};
