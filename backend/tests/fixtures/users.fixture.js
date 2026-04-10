// Test Fixtures for Users
const bcrypt = require('bcrypt');

const USERS = {
  superadmin: {
    id: 1,
    emp_code: 'ADMIN-001',
    name: 'Admin User',
    email: 'admin@test.com',
    username: 'adminuser',
    password: 'Admin@1234',
    role: 'superadmin',
    department_id: null,
    manager_id: null,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  management: {
    id: 2,
    emp_code: 'MGT-001',
    name: 'Management User',
    email: 'management@test.com',
    username: 'managementuser',
    password: 'Management@1234',
    role: 'management',
    department_id: 1,
    manager_id: null,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  deptHead: {
    id: 3,
    emp_code: 'HEAD-001',
    name: 'Department Head',
    email: 'depthead@test.com',
    username: 'depthead',
    password: 'DeptHead@1234',
    role: 'department_head',
    department_id: 1,
    manager_id: null,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  manager: {
    id: 4,
    emp_code: 'MGR-001',
    name: 'Manager User',
    email: 'manager@test.com',
    username: 'manager',
    password: 'Manager@1234',
    role: 'manager',
    department_id: 1,
    manager_id: 3,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  employee1: {
    id: 5,
    emp_code: 'EMP-001',
    name: 'Employee One',
    email: 'employee1@test.com',
    username: 'employee1',
    password: 'Employee@1234',
    role: 'employee',
    department_id: 1,
    manager_id: 4,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  employee2: {
    id: 6,
    emp_code: 'EMP-002',
    name: 'Employee Two',
    email: 'employee2@test.com',
    username: 'employee2',
    password: 'Employee@1234',
    role: 'employee',
    department_id: 1,
    manager_id: 4,
    is_active: true,
    created_at: new Date(),
    updated_at: new Date()
  },
  inactiveUser: {
    id: 7,
    emp_code: 'INACTIVE-001',
    name: 'Inactive User',
    email: 'inactive@test.com',
    username: 'inactiveuser',
    password: 'Inactive@1234',
    role: 'employee',
    department_id: 1,
    manager_id: 4,
    is_active: false,
    created_at: new Date(),
    updated_at: new Date()
  }
};

/**
 * Get user with password hash
 * @param {string} userKey - Key from USERS object
 * @returns {Promise<Object>}
 */
async function getUserWithHash(userKey) {
  if (!USERS[userKey]) {
    throw new Error(`User fixture '${userKey}' not found`);
  }

  const user = { ...USERS[userKey] };
  const plainPassword = user.password;
  delete user.password;

  user.password_hash = await bcrypt.hash(plainPassword, 10);
  return user;
}

/**
 * Get all users with password hashes
 * @returns {Promise<Array>}
 */
async function getAllUsersWithHashes() {
  const users = [];
  for (const [key, user] of Object.entries(USERS)) {
    const userWithHash = await getUserWithHash(key);
    users.push(userWithHash);
  }
  return users;
}

module.exports = {
  USERS,
  getUserWithHash,
  getAllUsersWithHashes
};
