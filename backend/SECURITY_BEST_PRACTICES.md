# Security Best Practices Guide

## Table of Contents

1. [For Developers](#for-developers)
2. [For DevOps/Deployment](#for-devopsdeployment)
3. [For Code Review](#for-code-review)
4. [Vulnerability Reporting](#vulnerability-reporting)
5. [Security Checklist](#security-checklist)

---

## For Developers

### 1. Input Validation & Sanitization

#### ✅ DO

```javascript
// Use validation middleware
const { validateEmailField, handleValidationErrors } = require('./middleware/requestValidator');

router.post('/register', [
  validateEmailField('email'),
  handleValidationErrors
], handler);

// Sanitize string inputs
const { sanitizeInput } = require('./utils/securityUtils');
const cleanInput = sanitizeInput(userInput);

// Check for injection patterns
const { hasSQLInjectionPattern, hasXSSPattern } = require('./utils/securityUtils');
if (hasSQLInjectionPattern(input) || hasXSSPattern(input)) {
  return res.status(400).json({ error: 'Invalid input' });
}
```

#### ❌ DON'T

```javascript
// Don't accept unvalidated input
router.post('/register', (req, res) => {
  const email = req.body.email; // No validation!
  User.create({ email });
});

// Don't concatenate strings into queries
const query = `SELECT * FROM users WHERE email = '${email}'`; // SQL injection!

// Don't log sensitive data
logger.info(`User logged in with password: ${password}`); // Never!
```

---

### 2. Password Security

#### ✅ DO

```javascript
// Use password service
const passwordService = require('./services/passwordService');

// Hash passwords
const hash = await passwordService.hashPassword(password);
user.password_hash = hash;

// Verify passwords
const isValid = await passwordService.verifyPassword(inputPassword, hash);

// Validate strength
const result = passwordService.validatePasswordStrength(password);
if (!result.isValid) {
  return res.status(400).json({ errors: result.errors });
}

// Check password age
const status = passwordService.checkPasswordStatus(user.password_changed_at);
if (status.isOverdue) {
  // Force password change
}
```

#### ❌ DON'T

```javascript
// Don't store plain text passwords
user.password = password; // Never!

// Don't use weak hashing
const hash = crypto.createHash('md5').update(password).digest('hex');

// Don't use default/simple passwords
const password = '12345'; // Bad!

// Don't log passwords
logger.info(`Password: ${password}`); // Never!
```

---

### 3. Authentication & JWT

#### ✅ DO

```javascript
// Check authentication
const { authenticate, requireRole } = require('./middleware/auth');

router.get('/protected', authenticate, (req, res) => {
  const user = req.user; // Safe, verified user
  res.json({ user });
});

// Check authorization
router.delete('/users/:id',
  authenticate,
  requireRole('superadmin', 'management'),
  deleteHandler
);

// Verify token expiry
if (err.name === 'TokenExpiredError') {
  return res.status(401).json({ error: 'Token expired, please login again' });
}
```

#### ❌ DON'T

```javascript
// Don't skip authentication on sensitive operations
router.delete('/users/:id', deleteHandler); // No auth check!

// Don't trust JWT without verification
const decoded = jwt.decode(token); // No verification!

// Don't expose sensitive user data
router.get('/user/:id', (req, res) => {
  res.json(user); // Includes password_hash!
});
```

---

### 4. Database & Queries

#### ✅ DO

```javascript
// Use Sequelize ORM (parameterized queries)
const user = await User.findOne({
  where: { email: userEmail }
});

// Use proper associations
const task = await Task.findByPk(id, {
  include: [
    { association: 'creator', attributes: ['id', 'name'] },
    { association: 'assignee', attributes: ['id', 'name'] }
  ]
});

// Exclude sensitive fields
const users = await User.findAll({
  attributes: { exclude: ['password_hash'] }
});

// Use transactions for atomic operations
const transaction = await sequelize.transaction();
try {
  await User.create(data, { transaction });
  await UserProfile.create(profileData, { transaction });
  await transaction.commit();
} catch (error) {
  await transaction.rollback();
}
```

#### ❌ DON'T

```javascript
// Don't concatenate queries
const query = `SELECT * FROM users WHERE email = '${email}'`; // SQL injection!

// Don't select all fields
const users = await User.findAll(); // Includes password_hash!

// Don't skip validation before queries
const user = await User.findByPk(userInput); // Not validated!

// Don't skip transactions
await User.create(data);
await UserProfile.create(profileData); // One fails, other succeeds!
```

---

### 5. Error Handling

#### ✅ DO

```javascript
// Log detailed errors for debugging
logger.error('Database error', {
  error: error.message,
  stack: error.stack,
  userId: req.user?.id,
  endpoint: req.path
});

// Return generic errors to client
res.status(500).json({
  success: false,
  message: 'An error occurred while processing your request'
});

// In development, include stack trace
if (process.env.NODE_ENV === 'development') {
  res.status(500).json({
    success: false,
    message: 'An error occurred while processing your request',
    stack: error.stack
  });
}
```

#### ❌ DON'T

```javascript
// Don't expose error details to clients
res.status(500).json({
  error: 'TypeError: Cannot read property email of undefined'
}); // Reveals code structure!

// Don't log sensitive data
logger.error(`Login failed for ${email} with password ${password}`); // Never!

// Don't reveal database structure
res.status(400).json({
  error: 'Foreign key constraint failed on users.company_id'
}); // Reveals schema!
```

---

### 6. Rate Limiting & CSRF

#### ✅ DO

```javascript
// Use rate limiting middleware
const { authLimiter } = require('./middleware/rateLimiter');
router.post('/auth/login', authLimiter, loginHandler);

// Check CSRF tokens
const { checkCSRFToken } = require('./middleware/csrf');
router.post('/tasks', checkCSRFToken, createTaskHandler);

// Include CSRF token in responses
res.json({
  success: true,
  csrfToken: req.csrfToken,
  data: taskData
});
```

#### ❌ DON'T

```javascript
// Don't skip rate limiting on sensitive endpoints
router.post('/auth/login', loginHandler); // No rate limit!

// Don't skip CSRF protection
router.post('/tasks', createTaskHandler); // No CSRF check!

// Don't reuse CSRF tokens
// (handled automatically by middleware)
```

---

### 7. File Upload Security

#### ✅ DO

```javascript
// Validate file uploads
const { validateFileUpload } = require('./utils/securityUtils');

router.post('/upload', upload.single('file'), (req, res) => {
  const validation = validateFileUpload(req.file);
  if (!validation.isValid) {
    return res.status(400).json({ error: validation.error });
  }
  // Process file
});

// Sanitize filenames
const { sanitizeFilename } = require('./utils/securityUtils');
const safeName = sanitizeFilename(req.file.originalname);

// Store files outside web root
// Use timestamps to prevent collisions
const filename = `${Date.now()}_${safeName}`;
const path = `/uploads/${filename}`;
```

#### ❌ DON'T

```javascript
// Don't trust file extensions
if (req.file.originalname.endsWith('.pdf')) {
  // A .php file renamed to .pdf will still execute!
}

// Don't store files in web root
const path = `./public/${req.file.originalname}`; // Can be accessed directly!

// Don't use original filenames
fs.writeFileSync(req.file.originalname, buffer); // Collision & security risk!
```

---

### 8. Environment & Secrets

#### ✅ DO

```javascript
// Use environment variables for secrets
const dbPassword = process.env.DBPASS;
const jwtSecret = process.env.JWT_SECRET;

// Validate required variables at startup
const required = ['JWT_SECRET', 'DBPASS', 'DBUSER'];
required.forEach(variable => {
  if (!process.env[variable]) {
    throw new Error(`Missing required environment variable: ${variable}`);
  }
});

// Use strong random secrets
// Generate: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
// Min 32 characters, truly random
```

#### ❌ DON'T

```javascript
// Don't hardcode secrets
const jwtSecret = 'my-secret-key'; // Never!

// Don't store secrets in code
const dbPassword = 'admin123'; // Never!

// Don't use weak secrets
const secret = 'secret'; // Too weak!

// Don't commit .env to git
git add .env # Never!
```

---

## For DevOps/Deployment

### 1. HTTPS/SSL

#### ✅ DO

```bash
# Use strong SSL/TLS certificates
# Use Let's Encrypt for free certificates
certbot certonly --standalone -d example.com

# Configure HSTS headers (already in app)
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# Enforce HTTPS redirects
# Configure in reverse proxy (Nginx/Apache)
if ($scheme != "https") {
  return 301 https://$server_name$request_uri;
}
```

#### ❌ DON'T

```bash
# Don't use self-signed certificates in production
# Don't use HTTP without HTTPS redirect
# Don't use weak SSL/TLS protocols (SSLv2, SSLv3, TLS 1.0)
```

---

### 2. Database Security

#### ✅ DO

```bash
# Use strong database passwords (min 20 chars, mixed case, numbers, special chars)
# Generate: openssl rand -base64 32

# Limit database user permissions
# Create app-specific user with minimal permissions
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON database.* TO 'app_user'@'localhost';

# Use connection pooling
const sequelize = new Sequelize({
  host: process.env.DBHOST,
  database: process.env.DBNAME,
  username: process.env.DBUSER,
  password: process.env.DBPASS,
  pool: {
    max: 10,
    min: 2,
    acquire: 30000,
    idle: 10000
  }
});

# Enable SSL for database connections (if remote)
# Set SSL_MODE to REQUIRED for production
```

#### ❌ DON'T

```bash
# Don't use default credentials
# Don't use simple passwords like 'password' or '123456'
# Don't give app user admin/root permissions
# Don't expose database ports to the internet
```

---

### 3. Logging & Monitoring

#### ✅ DO

```bash
# Enable comprehensive logging
# Logs should include:
# - All authentication attempts
# - All authorization checks
# - All data modifications
# - All security events
# - All errors with context

# Configure log rotation
# Logs should be deleted after 30 days

# Monitor logs for suspicious activity
# Set up alerts for:
# - Multiple failed login attempts
# - Unusual traffic patterns
# - Rate limit violations
# - Authorization failures

# Use centralized logging (ELK, Splunk, etc.)
# Secure logs (encrypted transmission & storage)
```

#### ❌ DON'T

```bash
# Don't store logs in application directory (fills disk)
# Don't log sensitive data (passwords, tokens, PII)
# Don't skip logging on sensitive operations
# Don't make logs world-readable
```

---

### 4. Backups & Recovery

#### ✅ DO

```bash
# Daily automated backups
# Store backups off-site
# Test recovery process regularly
# Encrypt backups
# Keep multiple versions (daily, weekly, monthly)

# Example backup script
#!/bin/bash
BACKUP_DIR="/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"

mysqldump -u$DBUSER -p$DBPASS $DBNAME | gzip > $BACKUP_FILE
# Upload to secure storage
aws s3 cp $BACKUP_FILE s3://backup-bucket/
```

#### ❌ DON'T

```bash
# Don't keep backups only on local server
# Don't skip backup verification
# Don't store backups unencrypted
# Don't keep backups for less than 30 days
```

---

### 5. Access Control

#### ✅ DO

```bash
# Use strong SSH keys (4096-bit RSA or Ed25519)
# ssh-keygen -t ed25519 -C "deploy@example.com"

# Disable password authentication for SSH
# Only allow key-based authentication

# Use firewall rules
# Only expose necessary ports (80, 443)
# Restrict admin access by IP

# Enable 2FA for admin accounts
# Use TOTP (Time-based One-Time Password)

# Regularly rotate credentials
# SSH keys every 6 months
# Database passwords every 90 days
```

#### ❌ DON'T

```bash
# Don't use simple SSH passwords
# Don't allow root login via SSH
# Don't expose database ports to the internet
# Don't share SSH keys between developers
# Don't store secrets in shell history
```

---

## For Code Review

### Security Review Checklist

#### Authentication & Authorization
- [ ] All sensitive endpoints require authentication
- [ ] Authentication checks cannot be bypassed
- [ ] Role-based access control is properly implemented
- [ ] User roles are verified server-side (not client-side)
- [ ] Password changes require current password verification

#### Input Validation
- [ ] All user inputs are validated
- [ ] Validation uses whitelist approach
- [ ] Input length limits are enforced
- [ ] File uploads are validated (type, size)
- [ ] No SQL injection vulnerabilities

#### Data Protection
- [ ] Passwords are hashed with bcrypt
- [ ] Sensitive data is not logged
- [ ] Sensitive fields are excluded from responses
- [ ] Database credentials are in environment variables
- [ ] JWT secrets are strong and secret

#### Error Handling
- [ ] Generic error messages are returned to clients
- [ ] Detailed errors are logged for debugging
- [ ] Stack traces are not exposed in production
- [ ] Error handling doesn't reveal system information

#### Rate Limiting & CSRF
- [ ] Rate limiting is applied to sensitive endpoints
- [ ] CSRF tokens are required for state-changing operations
- [ ] CSRF tokens are validated
- [ ] Account lockout is implemented

#### Security Headers
- [ ] Security headers are present
- [ ] CSP is properly configured
- [ ] HSTS is enabled
- [ ] X-Frame-Options prevents clickjacking

---

## Vulnerability Reporting

### How to Report Security Vulnerabilities

#### ⚠️ IMPORTANT: DO NOT create public GitHub issues for security vulnerabilities

### Responsible Disclosure Process

1. **Email Security Team**
   - Email: security@studioinfinito.com
   - Subject: `[SECURITY] Vulnerability Report - {Vulnerability Type}`

2. **Include in Report**
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)
   - Your contact information

3. **Expected Timeline**
   - Acknowledgment: Within 24 hours
   - Initial response: Within 5 business days
   - Fix deployed: Within 30 days (depending on severity)
   - Public disclosure: After fix is deployed

4. **Vulnerability Severity**

   | Level | CVSS | Response | Examples |
   |-------|------|----------|----------|
   | Critical | 9.0-10.0 | 24 hours | Remote code execution, auth bypass |
   | High | 7.0-8.9 | 2 days | SQL injection, XSS, CSRF |
   | Medium | 4.0-6.9 | 5 days | Information disclosure, weak auth |
   | Low | 0.1-3.9 | 30 days | Minor issues, best practices |

### Bug Bounty Program

We offer rewards for reported vulnerabilities:
- **Critical**: $1000-5000
- **High**: $500-1000
- **Medium**: $100-500
- **Low**: Recognition only

---

## Security Checklist

### Pre-Development
- [ ] Security requirements defined
- [ ] Threat model created
- [ ] Security tools configured
- [ ] Team trained on security

### During Development
- [ ] Code follows security guidelines
- [ ] Security reviews are performed
- [ ] Dependencies are kept updated
- [ ] No hardcoded secrets
- [ ] Logging is secure

### Pre-Deployment
- [ ] All tests pass
- [ ] Security audit completed
- [ ] Vulnerabilities fixed
- [ ] Dependencies verified
- [ ] Environment variables configured
- [ ] Backups tested
- [ ] Monitoring configured
- [ ] HTTPS enabled
- [ ] Firewall rules set

### Post-Deployment
- [ ] All features working correctly
- [ ] Logs being collected
- [ ] Monitoring alerts active
- [ ] Backups running
- [ ] Team trained on new features
- [ ] Documentation updated
- [ ] Incident response plan ready

### Ongoing Maintenance
- [ ] Regular security audits
- [ ] Dependency updates
- [ ] Log reviews
- [ ] Access control reviews
- [ ] Backup verification
- [ ] Incident drills
- [ ] Team training updates

---

## Resources

### Internal Documentation
- `SECURITY_HARDENING_GUIDE.md` - Detailed implementation guide
- `src/constants/security.js` - Security configuration
- `src/utils/securityUtils.js` - Security utility functions

### External Resources
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Express.js Security](https://expressjs.com/en/advanced/best-practice-security.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

**Version:** Phase 3 - Security Hardening  
**Last Updated:** April 7, 2026  
**Maintained By:** Security Team
