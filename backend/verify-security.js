#!/usr/bin/env node

/**
 * Security Hardening Verification Script
 * Checks that all Phase 3 security implementations are in place
 */

const fs = require('fs');
const path = require('path');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[36m'
};

const checks = [];
let passCount = 0;
let failCount = 0;
let warnCount = 0;

/**
 * Log a passing check
 */
function logPass(message, details = '') {
  console.log(`${colors.green}✓ PASS${colors.reset} ${message}`);
  if (details) {
    console.log(`  ${details}`);
  }
  passCount++;
  checks.push({ status: 'pass', message });
}

/**
 * Log a failing check
 */
function logFail(message, details = '') {
  console.log(`${colors.red}✗ FAIL${colors.reset} ${message}`);
  if (details) {
    console.log(`  ${details}`);
  }
  failCount++;
  checks.push({ status: 'fail', message });
}

/**
 * Log a warning
 */
function logWarn(message, details = '') {
  console.log(`${colors.yellow}⚠ WARN${colors.reset} ${message}`);
  if (details) {
    console.log(`  ${details}`);
  }
  warnCount++;
  checks.push({ status: 'warn', message });
}

/**
 * Check if file exists
 */
function fileExists(filePath) {
  return fs.existsSync(filePath);
}

/**
 * Check if file contains content
 */
function fileContains(filePath, content) {
  if (!fileExists(filePath)) {
    return false;
  }
  const fileContent = fs.readFileSync(filePath, 'utf8');
  if (Array.isArray(content)) {
    return content.every(c => fileContent.includes(c));
  }
  return fileContent.includes(content);
}

console.log(`\n${colors.blue}═══════════════════════════════════════════════════${colors.reset}`);
console.log(`${colors.blue}Phase 3: Security Hardening Verification${colors.reset}`);
console.log(`${colors.blue}═══════════════════════════════════════════════════${colors.reset}\n`);

// ===== 1. Security Middleware Files =====
console.log(`${colors.blue}1. Security Middleware Files${colors.reset}`);

if (fileExists('src/middleware/securityHeaders.js')) {
  logPass('Security headers middleware exists');
} else {
  logFail('Security headers middleware missing', 'Expected: src/middleware/securityHeaders.js');
}

if (fileExists('src/middleware/csrf.js')) {
  logPass('CSRF middleware exists');
} else {
  logFail('CSRF middleware missing', 'Expected: src/middleware/csrf.js');
}

if (fileExists('src/middleware/requestValidator.js')) {
  logPass('Request validator middleware exists');
} else {
  logFail('Request validator middleware missing', 'Expected: src/middleware/requestValidator.js');
}

if (fileExists('src/middleware/accountLockout.js')) {
  logPass('Account lockout middleware exists');
} else {
  logFail('Account lockout middleware missing', 'Expected: src/middleware/accountLockout.js');
}

// ===== 2. Security Utilities =====
console.log(`\n${colors.blue}2. Security Utilities${colors.reset}`);

if (fileExists('src/utils/securityUtils.js')) {
  logPass('Security utilities exist');
  if (fileContains('src/utils/securityUtils.js', [
    'validatePasswordStrength',
    'sanitizeInput',
    'hasXSSPattern',
    'hasSQLInjectionPattern'
  ])) {
    logPass('Security utilities include required functions');
  } else {
    logFail('Security utilities missing required functions');
  }
} else {
  logFail('Security utilities missing', 'Expected: src/utils/securityUtils.js');
}

if (fileExists('src/constants/security.js')) {
  logPass('Security constants exist');
} else {
  logFail('Security constants missing', 'Expected: src/constants/security.js');
}

if (fileExists('src/services/passwordService.js')) {
  logPass('Password service exists');
} else {
  logFail('Password service missing', 'Expected: src/services/passwordService.js');
}

// ===== 3. App Configuration =====
console.log(`\n${colors.blue}3. Application Configuration${colors.reset}`);

if (fileContains('src/app.js', [
  'helmet',
  'express-mongo-sanitize',
  'morgan',
  'sanitizeRequestBody',
  'applyAllSecurityHeaders'
])) {
  logPass('App includes all security middleware');
} else {
  logFail('App missing some security middleware');
}

if (fileContains('src/app.js', 'Strict-Transport-Security')) {
  logPass('HSTS headers configured');
} else {
  logWarn('HSTS headers may not be properly configured');
}

if (fileContains('src/app.js', 'Content-Security-Policy')) {
  logPass('CSP headers configured');
} else {
  logWarn('CSP headers may not be properly configured');
}

// ===== 4. Package Dependencies =====
console.log(`\n${colors.blue}4. Package Dependencies${colors.reset}`);

const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const requiredPackages = [
  'helmet',
  'express-validator',
  'morgan',
  'bcrypt',
  'express-rate-limit',
  'express-mongo-sanitize',
  'validator',
  'xss-clean',
  'cors'
];

requiredPackages.forEach(pkg => {
  if (packageJson.dependencies[pkg]) {
    logPass(`${pkg} installed`);
  } else {
    logFail(`${pkg} not installed`);
  }
});

// ===== 5. Documentation =====
console.log(`\n${colors.blue}5. Documentation${colors.reset}`);

if (fileExists('SECURITY_HARDENING_GUIDE.md')) {
  logPass('Security Hardening Guide exists');
} else {
  logFail('Security Hardening Guide missing', 'Expected: SECURITY_HARDENING_GUIDE.md');
}

if (fileExists('SECURITY_BEST_PRACTICES.md')) {
  logPass('Security Best Practices Guide exists');
} else {
  logFail('Security Best Practices Guide missing', 'Expected: SECURITY_BEST_PRACTICES.md');
}

// ===== 6. Feature Implementation =====
console.log(`\n${colors.blue}6. Security Features Implementation${colors.reset}`);

// Rate limiting
if (fileContains('src/middleware/rateLimiter.js', [
  'authLimiter',
  'apiLimiter',
  'importExportLimiter'
])) {
  logPass('Rate limiting properly implemented');
} else {
  logFail('Rate limiting incomplete');
}

// CSRF tokens
if (fileContains('src/middleware/csrf.js', [
  'validateCSRFToken',
  'generateCSRFToken',
  'startTokenCleanup'
])) {
  logPass('CSRF protection properly implemented');
} else {
  logFail('CSRF protection incomplete');
}

// Account lockout
if (fileContains('src/middleware/accountLockout.js', [
  'recordFailedLoginAttempt',
  'checkAccountLockout',
  'startLockoutCleanup'
])) {
  logPass('Account lockout properly implemented');
} else {
  logFail('Account lockout incomplete');
}

// Password validation
if (fileContains('src/services/passwordService.js', [
  'validatePasswordStrength',
  'generatePasswordResetToken',
  'verifyPasswordResetToken'
])) {
  logPass('Password security properly implemented');
} else {
  logFail('Password security incomplete');
}

// Input validation
if (fileContains('src/middleware/requestValidator.js', [
  'validateEmailField',
  'validatePasswordField',
  'handleValidationErrors',
  'sanitizeRequestBody'
])) {
  logPass('Input validation properly implemented');
} else {
  logFail('Input validation incomplete');
}

// ===== 7. Security Constants =====
console.log(`\n${colors.blue}7. Security Constants${colors.reset}`);

const securityConsts = [
  { const: 'MIN_LENGTH', check: 'PASSWORD' },
  { const: 'BCRYPT_ROUNDS', check: 'PASSWORD' },
  { const: 'MAX_LOGIN_ATTEMPTS', check: 'ACCOUNT_LOCKOUT' },
  { const: 'EXPIRY_HOURS', check: 'JWT' }
];

// Check if security constants file exists and is valid
const secConstContent = fs.readFileSync('src/constants/security.js', 'utf8');
const hasConstants = securityConsts.every(({ const: constName, check }) => 
  secConstContent.includes(constName)
);

if (hasConstants) {
  logPass('Security constants properly defined');
} else {
  logFail('Some security constants are missing or improperly defined');
}

// ===== 8. Environment Variables =====
console.log(`\n${colors.blue}8. Environment Configuration${colors.reset}`);

if (fileExists('.env.example')) {
  logPass('.env.example exists');
  if (fileContains('.env.example', [
    'JWT_SECRET',
    'DBPASS',
    'CORS_ORIGINS'
  ])) {
    logPass('Environment variables documented');
  } else {
    logWarn('Some important environment variables not documented');
  }
} else {
  logWarn('.env.example missing - create for documentation');
}

if (process.env.JWT_SECRET && process.env.JWT_SECRET.length >= 32) {
  logPass('JWT_SECRET configured and strong');
} else {
  logWarn('JWT_SECRET may not be configured or strong enough');
}

// ===== 9. Error Handling =====
console.log(`\n${colors.blue}9. Error Handling${colors.reset}`);

if (fileContains('src/middleware/errorHandler.js', [
  'SequelizeValidationError',
  'JsonWebTokenError',
  'process.env.NODE_ENV === \'development\''
])) {
  logPass('Error handling properly implemented');
} else {
  logFail('Error handling may be incomplete');
}

// ===== 10. Logging =====
console.log(`\n${colors.blue}10. Request Logging${colors.reset}`);

if (fileContains('src/app.js', 'morgan')) {
  logPass('Morgan logging configured');
} else {
  logFail('Morgan logging not configured');
}

if (fileExists('src/utils/logger.js')) {
  logPass('Logger utility exists');
} else {
  logFail('Logger utility missing');
}

// ===== Summary =====
console.log(`\n${colors.blue}═══════════════════════════════════════════════════${colors.reset}`);
console.log(`${colors.blue}Summary${colors.reset}`);
console.log(`${colors.blue}═══════════════════════════════════════════════════${colors.reset}\n`);

console.log(`${colors.green}Passed: ${passCount}${colors.reset}`);
console.log(`${colors.red}Failed: ${failCount}${colors.reset}`);
console.log(`${colors.yellow}Warnings: ${warnCount}${colors.reset}`);

const totalChecks = passCount + failCount + warnCount;
const passPercentage = Math.round((passCount / totalChecks) * 100);

console.log(`\nCompletion: ${passPercentage}% (${passCount}/${totalChecks})`);

// ===== Recommendations =====
if (failCount > 0 || warnCount > 0) {
  console.log(`\n${colors.yellow}Recommendations:${colors.reset}`);

  if (failCount > 0) {
    console.log(`${colors.red}1. Fix ${failCount} failed checks before deployment${colors.reset}`);
  }

  if (warnCount > 0) {
    console.log(`${colors.yellow}2. Address ${warnCount} warnings for optimal security${colors.reset}`);
  }

  console.log(`3. Review the SECURITY_HARDENING_GUIDE.md for details`);
  console.log(`4. Test security features before deployment`);
}

// ===== Next Steps =====
if (passCount === totalChecks) {
  console.log(`\n${colors.green}✓ All security checks passed!${colors.reset}`);
  console.log(`${colors.green}Next steps:${colors.reset}`);
  console.log(`1. Run security tests: npm test`);
  console.log(`2. Review sensitive code in code review`);
  console.log(`3. Deploy to staging environment`);
  console.log(`4. Test security features in staging`);
  console.log(`5. Deploy to production`);
}

console.log(`\n`);

// Exit with appropriate code
process.exit(failCount > 0 ? 1 : 0);
