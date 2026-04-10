/**
 * Security Constants and Configuration
 * Centralized security settings for the application
 */

module.exports = {
  // Password Security
  PASSWORD: {
    MIN_LENGTH: 8,
    MIN_UPPERCASE: 1,
    MIN_LOWERCASE: 1,
    MIN_NUMBERS: 1,
    MIN_SPECIAL_CHARS: 1,
    SPECIAL_CHARS_REGEX: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/,
    BCRYPT_ROUNDS: 10,
    // Password reset token expiry in hours
    RESET_TOKEN_EXPIRY_HOURS: 24,
    // Password reset token length
    RESET_TOKEN_LENGTH: 32
  },

  // Account Lockout Settings
  ACCOUNT_LOCKOUT: {
    MAX_LOGIN_ATTEMPTS: 5,
    LOCKOUT_DURATION_MINUTES: 15,
    // Reset attempts after successful login (minutes)
    RESET_AFTER_MINUTES: 30
  },

  // JWT Configuration
  JWT: {
    // Token expiry time (hours)
    EXPIRY_HOURS: 24,
    // Refresh token expiry (days)
    REFRESH_TOKEN_EXPIRY_DAYS: 7,
    // Token refresh window (minutes before expiry when refresh is allowed)
    REFRESH_WINDOW_MINUTES: 60
  },

  // Rate Limiting
  RATE_LIMIT: {
    GENERAL: {
      WINDOW_MINUTES: 15,
      MAX_REQUESTS: 100
    },
    AUTH: {
      WINDOW_MINUTES: 15,
      MAX_REQUESTS: 5
    },
    SENSITIVE: {
      WINDOW_MINUTES: 1,
      MAX_REQUESTS: 3
    },
    FILE_UPLOAD: {
      WINDOW_HOURS: 1,
      MAX_REQUESTS: 20
    }
  },

  // File Upload
  FILE_UPLOAD: {
    MAX_FILE_SIZE_MB: 50,
    ALLOWED_EXTENSIONS: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'txt', 'csv'],
    ALLOWED_MIME_TYPES: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip',
      'text/plain',
      'text/csv'
    ]
  },

  // Security Headers
  SECURITY_HEADERS: {
    // Content Security Policy
    CSP: {
      'default-src': ["'self'"],
      'script-src': ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
      'style-src': ["'self'", "'unsafe-inline'"],
      'img-src': ["'self'", 'data:', 'https:'],
      'font-src': ["'self'", 'data:'],
      'connect-src': ["'self'"],
      'frame-ancestors': ["'none'"],
      'base-uri': ["'self'"],
      'form-action': ["'self'"]
    },
    // HTTP Strict Transport Security
    HSTS: {
      maxAge: 31536000, // 1 year in seconds
      includeSubDomains: true,
      preload: true
    },
    // X-Frame-Options
    FRAME_OPTIONS: 'DENY',
    // X-Content-Type-Options
    CONTENT_TYPE_OPTIONS: 'nosniff',
    // X-XSS-Protection
    XSS_PROTECTION: '1; mode=block',
    // Referrer-Policy
    REFERRER_POLICY: 'strict-origin-when-cross-origin',
    // Permissions-Policy
    PERMISSIONS_POLICY: {
      'accelerometer': [],
      'camera': [],
      'geolocation': [],
      'gyroscope': [],
      'magnetometer': [],
      'microphone': [],
      'payment': [],
      'usb': []
    }
  },

  // CORS Configuration
  CORS: {
    METHODS: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    ALLOWED_HEADERS: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
    EXPOSED_HEADERS: ['X-Total-Count', 'X-Page-Number', 'RateLimit-Limit', 'RateLimit-Remaining']
  },

  // Session Configuration
  SESSION: {
    // Session cookie max age (ms)
    COOKIE_MAX_AGE: 24 * 60 * 60 * 1000, // 24 hours
    SECURE: true,
    HTTP_ONLY: true,
    SAME_SITE: 'strict'
  },

  // Input Validation
  INPUT: {
    // Maximum string length for general inputs
    MAX_STRING_LENGTH: 1000,
    // Maximum URL length
    MAX_URL_LENGTH: 2048,
    // Maximum email length
    MAX_EMAIL_LENGTH: 254,
    // Allowed characters in username
    USERNAME_PATTERN: /^[a-zA-Z0-9._-]{3,20}$/,
    // Allowed characters in phone
    PHONE_PATTERN: /^[\d\s+\-()]{7,20}$/
  },

  // Logging
  LOGGING: {
    // Log levels
    LEVELS: ['error', 'warn', 'info', 'debug'],
    // Log file retention (days)
    RETENTION_DAYS: 30,
    // Max log file size (MB)
    MAX_FILE_SIZE_MB: 10
  },

  // Sensitive Endpoints
  SENSITIVE_ENDPOINTS: [
    '/auth/login',
    '/auth/register',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/users/:id/change-password',
    '/admin/*'
  ],

  // Error Messages (Generic for security)
  ERROR_MESSAGES: {
    INVALID_CREDENTIALS: 'Invalid email or password',
    ACCOUNT_LOCKED: 'Account is locked due to too many login attempts. Please try again later.',
    INVALID_TOKEN: 'Invalid or expired token',
    INSUFFICIENT_PERMISSIONS: 'You do not have permission to access this resource',
    VALIDATION_ERROR: 'Invalid input provided',
    SERVER_ERROR: 'An error occurred while processing your request',
    NOT_FOUND: 'Resource not found',
    DUPLICATE_ENTRY: 'This resource already exists'
  }
};
