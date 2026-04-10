// Test Helper Utilities
const request = require('supertest');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

/**
 * Create a test JWT token
 * @param {Object} payload - Token payload
 * @param {string} secret - JWT secret
 * @returns {string} JWT token
 */
function createTestToken(payload, secret = process.env.JWT_SECRET) {
  return jwt.sign(payload, secret, { expiresIn: '24h' });
}

/**
 * Create a test user object
 * @param {Object} overrides - Override default values
 * @returns {Object} User object
 */
function createTestUser(overrides = {}) {
  return {
    id: 1,
    emp_code: 'TEST-001',
    name: 'Test User',
    email: 'test@example.com',
    username: 'testuser',
    password_hash: bcrypt.hashSync('Test@1234', 10),
    role: 'employee',
    department_id: 1,
    manager_id: null,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date(),
    ...overrides
  };
}

/**
 * Create a test task object
 * @param {Object} overrides - Override default values
 * @returns {Object} Task object
 */
function createTestTask(overrides = {}) {
  return {
    id: 1,
    title: 'Test Task',
    description: 'This is a test task',
    created_by: 1,
    assigned_to: 2,
    status: 'pending',
    priority: 'medium',
    target_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: null,
    created_at: new Date(),
    updated_at: new Date(),
    ...overrides
  };
}

/**
 * Create request with authentication header
 * @param {Object} app - Express app
 * @param {string} method - HTTP method (get, post, put, delete)
 * @param {string} path - API endpoint path
 * @param {Object} user - User object for token generation
 * @returns {Object} Supertest request with auth header
 */
function authenticatedRequest(app, method, path, user = {}) {
  const testUser = createTestUser(user);
  const token = createTestToken({
    id: testUser.id,
    email: testUser.email,
    role: testUser.role,
    username: testUser.username
  });

  return request(app)
    [method](path)
    .set('Authorization', `Bearer ${token}`)
    .set('Content-Type', 'application/json');
}

/**
 * Generate bcrypt hash for password
 * @param {string} password - Plain text password
 * @returns {string} Bcrypt hash
 */
async function hashPassword(password) {
  return bcrypt.hash(password, 10);
}

/**
 * Wait for async operation to complete
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise}
 */
function wait(ms = 1000) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Compare password with hash
 * @param {string} password - Plain text password
 * @param {string} hash - Bcrypt hash
 * @returns {Promise<boolean>}
 */
async function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

module.exports = {
  createTestToken,
  createTestUser,
  createTestTask,
  authenticatedRequest,
  hashPassword,
  wait,
  verifyPassword
};
