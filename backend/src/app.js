const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const xss = require('xss-clean');
const mongoSanitize = require('express-mongo-sanitize');
const morgan = require('morgan');
const config = require('./config');
const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const { apiLimiter, authLimiter } = require('./middleware/rateLimiter');
const logger = require('./utils/logger');
const { applyAllSecurityHeaders } = require('./middleware/securityHeaders');
const { checkAccountLockout } = require('./middleware/accountLockout');
const accountLockout = require('./middleware/accountLockout');
const { sanitizeRequestBody } = require('./middleware/requestValidator');
const { startTokenCleanup } = require('./middleware/csrf');
const csrf = require('./middleware/csrf');

const app = express();

// Trust Render/proxy X-Forwarded-For headers (required for express-rate-limit on Render)
app.set('trust proxy', 1);

// ===== PHASE 3: SECURITY HARDENING =====

// 1. Enhanced Security Headers with Helmet
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      fontSrc: ["'self'", "data:"],
      connectSrc: ["'self'"],
      frameAncestors: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"]
    }
  },
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true
  },
  xssFilter: true,
  noSniff: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
}));

// 2. Additional Security Headers
app.use(applyAllSecurityHeaders);

// 3. CORS configuration - support multiple origins
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);

    // Allow any localhost origin in development
    if (config.nodeEnv === 'development' && /^http:\/\/localhost(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }

    if (config.cors.origins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(`CORS blocked origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
  exposedHeaders: ['X-Total-Count', 'X-Page-Number', 'RateLimit-Limit', 'RateLimit-Remaining']
}));

// Handle preflight requests
app.options('*', cors());

// 4. Request Logging with Morgan
const morganFormat = ':remote-addr - :remote-user [:date[clf]] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent"';
app.use(morgan(morganFormat, {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}));

// 5. Body parsing middleware with size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 6. Serve uploaded files
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// 7. Data sanitization - protect against MongoDB injection
app.use(mongoSanitize({
  replaceWith: '_',
  onSanitize: ({ req, key }) => {
    logger.warn('Sanitized key detected', { key, path: req.path });
  }
}));

// 8. XSS protection (skip on Node 18+ where xss-clean may throw)
try { 
  app.use(xss()); 
} catch (_) {}

// 9. Additional request body sanitization
app.use(sanitizeRequestBody);

// 10. Rate limiting - General API
app.use('/api', apiLimiter);

// 11. Rate limiting - Authentication endpoints (stricter)
app.use('/api/v1/auth/login', authLimiter);
app.use('/api/v1/auth/register', authLimiter);
app.use('/api/v1/auth/forgot-password', authLimiter);

// 12. Account lockout check for login
app.post('/api/v1/auth/login', checkAccountLockout);

// 13. CSRF token initialization and cleanup
startTokenCleanup();

// 14. Account lockout cleanup
accountLockout.startLockoutCleanup();

// 15. Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('user-agent')
  });
  next();
});

// API routes
app.use('/api/v1', routes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Task Manager API',
    version: '1.0.0',
    status: 'running'
  });
});

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

module.exports = app;