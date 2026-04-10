/**
 * Security Headers Middleware
 * Implements comprehensive security headers for HTTP responses
 */

const securityConstants = require('../constants/security');
const logger = require('../utils/logger');

/**
 * Configure and apply security headers
 */
function securityHeadersMiddleware(req, res, next) {
  try {
    const config = securityConstants.SECURITY_HEADERS;

    // Strict Transport Security (HSTS)
    // Enforces HTTPS connection
    res.set('Strict-Transport-Security', 
      `max-age=${config.HSTS.maxAge}${config.HSTS.includeSubDomains ? '; includeSubDomains' : ''}${config.HSTS.preload ? '; preload' : ''}`
    );

    // Content Security Policy (CSP)
    // Controls which resources can be loaded
    const cspDirectives = Object.entries(config.CSP)
      .map(([key, values]) => `${key} ${values.join(' ')}`)
      .join('; ');
    res.set('Content-Security-Policy', cspDirectives);
    res.set('Content-Security-Policy-Report-Only', cspDirectives);

    // X-Content-Type-Options
    // Prevents MIME type sniffing
    res.set('X-Content-Type-Options', config.CONTENT_TYPE_OPTIONS);

    // X-Frame-Options
    // Prevents clickjacking attacks
    res.set('X-Frame-Options', config.FRAME_OPTIONS);

    // X-XSS-Protection
    // Browser XSS protection (legacy but still useful)
    res.set('X-XSS-Protection', config.XSS_PROTECTION);

    // Referrer-Policy
    // Controls how much referrer information is shared
    res.set('Referrer-Policy', config.REFERRER_POLICY);

    // Permissions-Policy (formerly Feature-Policy)
    // Controls which browser features can be used
    const permissionsPolicyDirectives = Object.entries(config.PERMISSIONS_POLICY)
      .map(([feature, allowlist]) => {
        if (allowlist.length === 0) {
          return `${feature}=()`;
        }
        return `${feature}=(${allowlist.join(' ')})`;
      })
      .join(', ');
    res.set('Permissions-Policy', permissionsPolicyDirectives);

    // Remove Server header to hide server information
    res.removeHeader('Server');
    res.removeHeader('X-Powered-By');

    // Set additional security headers
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('X-Frame-Options', 'DENY');
    res.set('X-XSS-Protection', '1; mode=block');

    next();
  } catch (error) {
    logger.error('Security headers middleware error:', error);
    next();
  }
}

/**
 * Configure CORS security headers
 */
function corsSecurity(req, res, next) {
  const config = securityConstants.SECURITY_HEADERS;

  // Set CORS headers with security headers
  res.set('Access-Control-Allow-Methods', securityConstants.CORS.METHODS.join(', '));
  res.set('Access-Control-Allow-Headers', securityConstants.CORS.ALLOWED_HEADERS.join(', '));
  res.set('Access-Control-Expose-Headers', securityConstants.CORS.EXPOSED_HEADERS.join(', '));
  res.set('Access-Control-Max-Age', '86400'); // 24 hours

  next();
}

/**
 * Add custom security headers
 */
function addCustomHeaders(req, res, next) {
  // Request ID for tracing
  if (!req.id && !req.headers['x-request-id']) {
    const requestId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    res.set('X-Request-ID', requestId);
    req.id = requestId;
  }

  // Timestamp header
  res.set('X-Response-Time', new Date().toISOString());

  next();
}

/**
 * Disable caching for sensitive endpoints
 */
function noCacheHeaders(req, res, next) {
  const sensitivePatterns = securityConstants.SENSITIVE_ENDPOINTS.map(endpoint => 
    endpoint.replace('*', '.*').replace(':', '\\d+')
  );

  const isSensitiveEndpoint = sensitivePatterns.some(pattern => 
    new RegExp(pattern).test(req.path)
  );

  if (isSensitiveEndpoint) {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');
    res.set('Surrogate-Control', 'no-store');
  }

  next();
}

/**
 * Apply all security headers
 */
function applyAllSecurityHeaders(req, res, next) {
  securityHeadersMiddleware(req, res, () => {
    corsSecurity(req, res, () => {
      addCustomHeaders(req, res, () => {
        noCacheHeaders(req, res, next);
      });
    });
  });
}

module.exports = {
  securityHeadersMiddleware,
  corsSecurity,
  addCustomHeaders,
  noCacheHeaders,
  applyAllSecurityHeaders
};
