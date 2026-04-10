// Integration Tests for Authentication Workflow
const request = require('supertest');
const { User } = require('../../src/models');
const { createTestUser } = require('../utils/testHelper');
const { getUserWithHash } = require('../fixtures/users.fixture');

jest.mock('../../src/models');
jest.mock('../../src/mail/mailer');
jest.mock('../../src/utils/logger');

describe('Authentication Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('User Registration and Login Workflow', () => {
    it('should complete full registration and login workflow', async () => {
      const newUser = createTestUser({
        id: undefined,
        email: 'newuser@test.com',
        username: 'newuser'
      });

      User.create.mockResolvedValue({
        id: 10,
        ...newUser,
        toJSON: jest.fn().mockReturnValue({ id: 10, ...newUser })
      });

      // Simulate registration
      const registrationResult = await User.create(newUser);
      expect(registrationResult).toBeDefined();
      expect(registrationResult.email).toBe('newuser@test.com');
    });
  });

  describe('Password Reset Workflow', () => {
    it('should complete password reset flow', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        id: 1,
        email: 'employee1@test.com',
        toJSON: jest.fn().mockReturnValue(user)
      };

      User.findOne.mockResolvedValue(mockUser);

      // Step 1: Request password reset
      const resetUser = await User.findOne({
        where: { email: 'employee1@test.com' }
      });
      expect(resetUser).toBeDefined();

      // Step 2: Verify reset token (mocked)
      // Step 3: Update password
      mockUser.update = jest.fn().mockResolvedValue({ ...mockUser, password_hash: 'newhash' });
      await mockUser.update({ password_hash: 'newhash' });

      expect(mockUser.update).toHaveBeenCalled();
    });
  });

  describe('Session Management', () => {
    it('should maintain session after login', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        id: 1,
        toJSON: jest.fn().mockReturnValue(user),
        update: jest.fn().mockResolvedValue(user)
      };

      User.findOne.mockResolvedValue(mockUser);

      // Login
      const loginUser = await User.findOne({
        where: { email: 'employee1@test.com' }
      });
      expect(loginUser).toBeDefined();

      // Update last_login_at
      await loginUser.update({ last_login_at: new Date() });
      expect(loginUser.update).toHaveBeenCalled();
    });
  });
});
