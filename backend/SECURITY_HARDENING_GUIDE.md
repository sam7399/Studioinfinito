# Phase 3: Security Hardening Implementation Guide

## Overview

This guide documents the comprehensive security hardening implementation for the Studioinfinito backend. It covers all security measures implemented to protect against common web vulnerabilities and attacks.

---

## Table of Contents

1. [Security Measures Implemented](#security-measures-implemented)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Security Headers](#security-headers)
5. [Input Sanitization & Validation](#input-sanitization--validation)
6. [CSRF Protection](#csrf-protection)
7. [Rate Limiting](#rate-limiting)
8. [Account Lockout](#account-lockout)
9. [Password Security](#password-security)
10. [JWT Authentication](#jwt-authentication)
11. [Request Logging](#request-logging)
12. [Testing Security](#testing-security)
13. [Deployment Checklist](#deployment-checklist)
14. [Incident Response](#incident-response)

---

## Security Measures Implemented

### 1. Input Sanitization & XSS Protection

**Files:**
- `src/middleware/requestValidator.js`
- `src/utils/securityUtils.js`
- `src/app.js`

**Implementation:**
- Express-validator for request validation
- XSS-clean middleware for malicious script detection
- HTML character escaping
- Pattern-based injection detection (SQL, XSS)
- Request body sanitization

**Usage:**
```javascript
const { 
  validateEmailField, 
  validatePasswordField,
  handleValidationErrors,
  sanitizeRequestBody 
} = require('./middleware/requestValidator');

// In routes
router.post('/register', [
  validateEmailField('email'),
  validatePasswordField('password'),
  handleValidationErrors
], authController.register);
```

**Protected Against:**
- XSS attacks
- SQL injection attempts
- HTML injection
- JavaScript injection

---

### 2. CSRF Protection

**Files:**
- `src/middleware/csrf.js`
- `src/constants/security.js`

**Implementation:**
- CSRF token generation and validation
- Token expiration (24 hours)
- One-time token usage
- Automatic token cleanup

**API Endpoints:**
- `GET /api/v1/csrf-token` - Get CSRF token

**Usage:**

```javascript
// Get CSRF token for client
fetch('/api/v1/csrf-token')
  .then(res => res.json())
  .then(data => {
    // Use data.csrfToken in X-CSRF-Token header
  });

// Include in requests
fetch('/api/v1/tasks', {
  method: 'POST',
  headers: {
    'X-CSRF-Token': csrfToken,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(taskData)
});
```

**Configuration:**
- Token expiry: 24 hours
- Token length: 32 bytes (256 bits)
- Cleanup interval: Hourly

---

### 3. Rate Limiting & Request Throttling

**Files:**
- `src/middleware/rateLimiter.js`
- `src/constants/security.js`

**Implemented Limits:**

| Endpoint | Limit | Window |
|----------|-------|--------|
| General API | 100 requests | 15 minutes |
| Authentication | 5 attempts | 15 minutes |
| Sensitive Operations | 3 requests | 1 minute |
| File Upload | 20 uploads | 1 hour |

**Usage:**
```javascript
const { apiLimiter, authLimiter } = require('./middleware/rateLimiter');

// Apply to routes
app.use('/api', apiLimiter);
app.post('/auth/login', authLimiter, authController.login);
```

**Response Headers:**
- `RateLimit-Limit`: Total requests allowed
- `RateLimit-Remaining`: Remaining requests
- `RateLimit-Reset`: When limit resets (Unix timestamp)

---

### 4. Security Headers

**Files:**
- `src/middleware/securityHeaders.js`
- `src/constants/security.js`

**Implemented Headers:**

| Header | Purpose | Value |
|--------|---------|-------|
| Strict-Transport-Security (HSTS) | Enforce HTTPS | max-age=31536000; includeSubDomains |
| Content-Security-Policy (CSP) | Control resource loading | Configured for safety |
| X-Content-Type-Options | Prevent MIME sniffing | nosniff |
| X-Frame-Options | Prevent clickjacking | DENY |
| X-XSS-Protection | Browser XSS filter | 1; mode=block |
| Referrer-Policy | Control referrer info | strict-origin-when-cross-origin |
| Permissions-Policy | Control browser features | Disabled for security |
| Cache-Control | Prevent caching of sensitive data | no-store, no-cache |

**Sensitive Endpoints:**
```javascript
// Automatically disable caching for:
- /auth/*
- /users/:id/change-password
- /admin/*
```

---

### 5. Request Validation Middleware

**Files:**
- `src/middleware/requestValidator.js`
- `src/utils/securityUtils.js`

**Validation Functions:**
- `validateEmailField()` - Email format validation
- `validatePasswordField()` - Password strength validation
- `validatePhoneField()` - Phone format validation
- `validateDateField()` - YYYY-MM-DD format validation
- `validateIdParam()` - Positive integer validation
- `validatePaginationParams()` - Page/limit validation
- `validateFileInRequest()` - File upload validation

**Example:**
```javascript
const { validateEmailField, validatePasswordField } = require('./middleware/requestValidator');

router.post('/register', [
  validateEmailField('email'),
  validatePasswordField('password'),
  handleValidationErrors
], registerHandler);
```

---

### 6. SQL Injection Prevention

**Implementation:**
- Sequelize ORM (parameterized queries)
- Input validation
- Pattern-based detection
- Database connection pooling

**Security Utils:**
```javascript
const { hasSQLInjectionPattern } = require('./utils/securityUtils');

if (hasSQLInjectionPattern(userInput)) {
  // Reject the request
  return res.status(400).json({ error: 'Invalid input' });
}
```

---

### 7. Password Security

**Files:**
- `src/services/passwordService.js`
- `src/utils/securityUtils.js`
- `src/constants/security.js`

**Requirements:**
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character

**Features:**
- Bcrypt hashing (10 rounds)
- Password strength validation
- Password expiry checking (90 days)
- Password reset tokens (24-hour expiry)
- Prevent password reuse

**Usage:**
```javascript
const passwordService = require('./services/passwordService');

// Hash password
const hash = await passwordService.hashPassword(password);

// Verify password
const isValid = await passwordService.verifyPassword(password, hash);

// Validate strength
const result = passwordService.validatePasswordStrength(password);
if (!result.isValid) {
  console.log(result.errors);
}

// Generate reset token
const { token, hash, expiresAt } = passwordService.generatePasswordResetToken();
```

---

### 8. Account Lockout

**Files:**
- `src/middleware/accountLockout.js`
- `src/constants/security.js`

**Configuration:**
- Max login attempts: 5
- Lockout duration: 15 minutes
- Reset attempts after: 30 minutes of inactivity

**Usage:**
```javascript
const lockout = require('./middleware/accountLockout');

// Check lockout status
const status = lockout.getLockoutStatus('user@example.com');
if (status.isLocked) {
  return res.status(429).json({ 
    message: 'Account locked',
    remainingMinutes: status.remainingMinutes 
  });
}

// Record failed attempt
lockout.recordFailedLoginAttempt('user@example.com');

// Clear attempts on success
lockout.clearFailedLoginAttempts('user@example.com');

// Unlock account (admin)
lockout.unlockAccount('user@example.com');
```

---

### 9. API Authentication

**JWT Configuration:**
- Token expiry: 24 hours
- Refresh token expiry: 7 days
- Refresh window: 60 minutes before expiry

**Features:**
- Token validation
- User verification
- Role-based access control
- Account status checking

**Middleware:**
```javascript
const { authenticate, requireRole } = require('./middleware/auth');

// Protect routes
router.get('/protected', authenticate, (req, res) => {
  // Access user: req.user
});

// Role-based protection
router.delete('/admin/users/:id', 
  authenticate,
  requireRole('superadmin', 'management'),
  deleteUserHandler
);
```

---

### 10. Data Sanitization

**Implementation:**
- MongoDB injection protection (express-mongo-sanitize)
- XSS protection (xss-clean)
- Request body sanitization
- HTML character escaping

**Protected Against:**
- NoSQL injection
- XSS attacks
- Prototype pollution
- Malicious scripts

---

### 11. Request Logging

**Files:**
- `src/app.js` (Morgan integration)
- `src/utils/logger.js`

**Logged Information:**
- IP address
- Request method and path
- HTTP status code
- Response size
- User agent
- Response time
- User ID (if authenticated)

**Log Format:**
```
:remote-addr - :remote-user [:date[clf]] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent"
```

**Security Events Logged:**
- Failed login attempts
- Account lockouts
- Rate limit violations
- Invalid CSRF tokens
- Authorization failures
- Sanitization events
- Validation errors

---

### 12. File Upload Security

**Configuration:**
- Maximum file size: 50 MB
- Allowed extensions: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, ZIP, TXT, CSV
- MIME type validation
- Filename sanitization

**Validation:**
```javascript
const { validateFileUpload } = require('./utils/securityUtils');

const validation = validateFileUpload(req.file);
if (!validation.isValid) {
  return res.status(400).json({ error: validation.error });
}
```

---

### 13. Environment Variables

**Required Security Variables:**
```env
# JWT
JWT_SECRET=<strong-random-string-min-32-chars>
JWT_EXPIRES_IN=24h

# CORS Origins
CORS_ORIGINS=https://example.com,https://app.example.com

# Database credentials (use strong passwords)
DBUSER=<secure-username>
DBPASS=<secure-password>

# Email credentials
EMAILPASS=<app-password-not-actual-password>

# Node environment
NODE_ENV=production
```

**Never commit secrets to version control. Use environment files.**

---

### 14. Error Handling

**Security Implementation:**
- Generic error messages to clients (hide internals)
- Detailed logging for administrators
- No stack traces exposed in production
- Proper HTTP status codes

**Error Messages:**
- `400 Bad Request` - Validation errors
- `401 Unauthorized` - Authentication failures
- `403 Forbidden` - Authorization failures
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server errors (no details)

**Development vs Production:**
```javascript
// Development: Include stack trace
if (process.env.NODE_ENV === 'development') {
  res.json({ error: message, stack: error.stack });
}

// Production: Hide details
res.json({ error: 'An error occurred' });
```

---

## Architecture

### Security Middleware Stack

```
Request
  ↓
1. Express.json/urlencoded (body parsing)
  ↓
2. Helmet (security headers)
  ↓
3. CORS (origin validation)
  ↓
4. Morgan (request logging)
  ↓
5. MongoDB Sanitize (NoSQL injection protection)
  ↓
6. XSS-clean (XSS protection)
  ↓
7. Request body sanitization
  ↓
8. Rate limiting
  ↓
9. CSRF token check
  ↓
10. Authentication
  ↓
11. Authorization
  ↓
12. Route handler
  ↓
13. Error handler
  ↓
Response
```

---

## Configuration

### Security Constants

Located in `src/constants/security.js`:

```javascript
{
  PASSWORD: {
    MIN_LENGTH: 8,
    BCRYPT_ROUNDS: 10,
    RESET_TOKEN_EXPIRY_HOURS: 24
  },
  ACCOUNT_LOCKOUT: {
    MAX_LOGIN_ATTEMPTS: 5,
    LOCKOUT_DURATION_MINUTES: 15
  },
  RATE_LIMIT: {
    GENERAL: { WINDOW_MINUTES: 15, MAX_REQUESTS: 100 },
    AUTH: { WINDOW_MINUTES: 15, MAX_REQUESTS: 5 }
  },
  JWT: {
    EXPIRY_HOURS: 24,
    REFRESH_TOKEN_EXPIRY_DAYS: 7
  }
}
```

### Customize Security Settings

Edit `src/constants/security.js` to adjust:
- Password requirements
- Lockout thresholds
- Rate limits
- JWT expiry times
- File upload limits

---

## Security Testing

### Manual Testing Checklist

#### 1. Authentication Security
- [ ] Attempt login with invalid credentials 5+ times (should lock account)
- [ ] Try to reset password with invalid email
- [ ] Verify password requirements are enforced
- [ ] Check that passwords are hashed (never logged in plain text)

#### 2. CSRF Protection
```bash
# Get CSRF token
curl http://localhost:5000/api/v1/csrf-token

# Try POST without CSRF token (should fail)
curl -X POST http://localhost:5000/api/v1/tasks

# Try POST with CSRF token (should succeed)
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "X-CSRF-Token: <token>"
```

#### 3. Rate Limiting
```bash
# Attempt login 6 times quickly
for i in {1..6}; do
  curl -X POST http://localhost:5000/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"test"}'
done
# 6th request should return 429
```

#### 4. Input Validation
```bash
# Test XSS attempt
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"title":"<script>alert(1)</script>"}'
# Should reject or sanitize

# Test SQL injection
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"title":"TEST\"; DROP TABLE tasks; --"}'
# Should reject or sanitize
```

#### 5. Security Headers
```bash
curl -i http://localhost:5000/api/v1/

# Look for headers:
# - Strict-Transport-Security
# - Content-Security-Policy
# - X-Content-Type-Options: nosniff
# - X-Frame-Options: DENY
# - X-XSS-Protection: 1; mode=block
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Set `NODE_ENV=production`
- [ ] Generate strong `JWT_SECRET` (min 32 characters, random)
- [ ] Configure `CORS_ORIGINS` with actual domains (no wildcards)
- [ ] Set strong database passwords
- [ ] Enable HTTPS/SSL certificates
- [ ] Configure rate limits for production traffic
- [ ] Set up log rotation (logs deleted after 30 days)
- [ ] Enable database backups
- [ ] Configure error monitoring (Sentry, etc.)
- [ ] Review all environment variables
- [ ] Run security verification script

### Deployment Command

```bash
# Install packages
npm install

# Run migrations
npm run db:migrate

# Start server
npm start  # Uses pm2 for process management
```

### Post-Deployment

- [ ] Test all authentication flows
- [ ] Verify HTTPS is enforced
- [ ] Check security headers in browser DevTools
- [ ] Test rate limiting
- [ ] Monitor error logs
- [ ] Verify backups are working
- [ ] Set up monitoring alerts

---

## Incident Response

### Security Incident Response Plan

#### Suspected Breach

1. **Immediate Actions**
   - Review logs for suspicious activity
   - Identify affected users
   - Preserve evidence (logs, backups)

2. **Containment**
   - Revoke compromised tokens
   - Lock affected accounts
   - Update security configurations

3. **Eradication**
   - Identify attack vector
   - Fix vulnerabilities
   - Review and update code

4. **Recovery**
   - Restore from clean backups
   - Force password resets for affected users
   - Notify users of incident
   - Monitor for further activity

#### Rate Limit Attack

1. Check IP addresses of requests
2. Temporarily block suspicious IPs
3. Increase rate limits or implement CAPTCHA for affected endpoints
4. Monitor for repeat attacks

#### Brute Force Attack

1. Identify target accounts
2. Lock accounts temporarily
3. Force password reset
4. Implement additional authentication (2FA)

---

## Security Best Practices

### For Developers

1. **Never log sensitive data**
   - Passwords, tokens, credit cards
   - Use generic messages in logs

2. **Validate all input**
   - From users, APIs, files, databases
   - Use whitelist approach

3. **Use parameterized queries**
   - Always use Sequelize ORM
   - Never construct SQL strings

4. **Keep dependencies updated**
   ```bash
   npm audit
   npm audit fix
   npm outdated
   ```

5. **Use environment variables**
   - Never hardcode secrets
   - Use `.env` for development only

### For Deployment

1. **Use HTTPS only**
   - Enable HSTS
   - Use strong SSL/TLS protocols

2. **Keep backups**
   - Daily database backups
   - Store off-site
   - Test restore process

3. **Monitor and log**
   - Enable request logging
   - Monitor for attacks
   - Set up alerts

4. **Regular updates**
   - Security patches for OS and dependencies
   - Framework updates
   - Database updates

5. **Access control**
   - Limit database user permissions
   - Use strong passwords
   - Enable 2FA for admin accounts

---

## Useful Commands

### Security Verification
```bash
# Run security verification script
node verify-security.js

# Check for vulnerabilities
npm audit

# Check for outdated packages
npm outdated
```

### Testing
```bash
# Run tests
npm test

# Test with coverage
npm test -- --coverage
```

### Logs
```bash
# View recent logs
tail -f logs/combined.log

# View error logs
tail -f logs/error.log

# Search logs
grep "Failed" logs/combined.log
```

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)
- [Express.js Security](https://expressjs.com/en/advanced/best-practice-security.html)
- [Helmet.js Documentation](https://helmetjs.github.io/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)

---

## Support & Questions

For security-related questions:
1. Check this guide
2. Review code comments
3. Contact security team
4. Report vulnerabilities privately

---

**Last Updated:** April 7, 2026  
**Version:** Phase 3 - Security Hardening  
**Maintained By:** Development Team
