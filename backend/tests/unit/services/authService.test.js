// Unit Tests for AuthService
const AuthService = require('../../../src/services/authService');
const { User, PasswordResetToken } = require('../../../src/models');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { getUserWithHash } = require('../../fixtures/users.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/mail/mailer');
jest.mock('../../../src/utils/logger');

describe('AuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('login', () => {
    it('should successfully login user with valid email and password', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        toJSON: jest.fn().mockReturnValue(user),
        update: jest.fn().mockResolvedValue(user),
        company_id: 1,
        force_password_change: false
      };

      User.findOne.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);

      const result = await AuthService.login('employee1@test.com', 'Employee@1234');

      expect(result).toHaveProperty('token');
      expect(result).toHaveProperty('user');
      expect(result.force_password_change).toBe(false);
      expect(User.findOne).toHaveBeenCalled();
      expect(mockUser.update).toHaveBeenCalledWith({ last_login_at: expect.any(Date) });
    });

    it('should successfully login user with valid username', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        toJSON: jest.fn().mockReturnValue(user),
        update: jest.fn().mockResolvedValue(user),
        company_id: 1,
        force_password_change: false
      };

      User.findOne.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);

      const result = await AuthService.login('employee1', 'Employee@1234');

      expect(result).toHaveProperty('token');
      expect(User.findOne).toHaveBeenCalledWith({
        where: { username: 'employee1' },
        include: expect.any(Array)
      });
    });

    it('should throw error for non-existent user', async () => {
      User.findOne.mockResolvedValue(null);

      await expect(AuthService.login('nonexistent@test.com', 'password')).rejects.toThrow('Invalid credentials');
    });

    it('should throw error for inactive user', async () => {
      const mockUser = {
        email: 'inactive@test.com',
        is_active: false
      };

      User.findOne.mockResolvedValue(mockUser);

      await expect(AuthService.login('inactive@test.com', 'password')).rejects.toThrow(
        'Account is inactive. Please contact your administrator.'
      );
    });

    it('should throw error for invalid password', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        is_active: true,
        toJSON: jest.fn().mockReturnValue(user)
      };

      User.findOne.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

      await expect(AuthService.login('employee1@test.com', 'wrongpassword')).rejects.toThrow('Invalid credentials');
    });

    it('should not include password_hash in response', async () => {
      const user = await getUserWithHash('employee1');
      const mockUser = {
        ...user,
        toJSON: jest.fn().mockReturnValue({
          ...user,
          password_hash: undefined
        }),
        update: jest.fn().mockResolvedValue(user),
        company_id: 1,
        force_password_change: false
      };

      User.findOne.mockResolvedValue(mockUser);
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);

      const result = await AuthService.login('employee1@test.com', 'Employee@1234');

      expect(result.user).not.toHaveProperty('password_hash');
    });
  });

  describe('forgotPassword', () => {
    it('should send password reset email for valid user', async () => {
      const mockUser = {
        id: 1,
        email: 'employee1@test.com'
      };

      User.findOne.mockResolvedValue(mockUser);
      PasswordResetToken.create.mockResolvedValue({});

      const result = await AuthService.forgotPassword('employee1@test.com');

      expect(result).toHaveProperty('message');
      expect(PasswordResetToken.create).toHaveBeenCalled();
    });

    it('should not reveal if email does not exist', async () => {
      User.findOne.mockResolvedValue(null);

      const result = await AuthService.forgotPassword('nonexistent@test.com');

      expect(result.message).toContain('If the email exists');
    });
  });
});
