const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { User, PasswordResetToken } = require('../models');
const config = require('../config');
const mailer = require('../mail/mailer');
const logger = require('../utils/logger');

class AuthService {
  /**
   * Login user with email and password
   */
  static async login(identifier, password) {
    // Accept email address or username
    const isEmail = String(identifier).includes('@');
    const where = isEmail
      ? { email: identifier.toLowerCase().trim() }
      : { username: identifier.toLowerCase().trim() };

    const user = await User.findOne({
      where,
      include: [
        { association: 'company', attributes: ['id', 'name'] },
        { association: 'department', attributes: ['id', 'name'] },
        { association: 'location', attributes: ['id', 'name'] }
      ]
    });

    if (!user) {
      throw new Error('Invalid credentials');
    }

    if (!user.is_active) {
      throw new Error('Account is inactive. Please contact your administrator.');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      throw new Error('Invalid credentials');
    }

    // Update last login
    await user.update({ last_login_at: new Date() });

    // Generate JWT token
    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role,
        company_id: user.company_id
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    // Remove password from response
    const userResponse = user.toJSON();
    delete userResponse.password_hash;

    return {
      token,
      user: userResponse,
      force_password_change: user.force_password_change
    };
  }

  /**
   * Request password reset
   */
  static async forgotPassword(email) {
    const user = await User.findOne({
      where: { email: email.toLowerCase() }
    });

    if (!user) {
      // Don't reveal if email exists
      return {
        message: 'If the email exists, a password reset link has been sent.'
      };
    }

    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto
      .createHash('sha256')
      .update(resetToken)
      .digest('hex');

    // Save token to database (expires in 1 hour)
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    await PasswordResetToken.create({
      user_id: user.id,
      token: hashedToken,
      expires_at: expiresAt
    });

    // Send email with reset link
    try {
      await mailer.sendPasswordReset(user.email, user.name, `${config.urls.app}/reset-password?token=${resetToken}`);
      logger.info(`Password reset email sent to: ${user.email}`);
    } catch (error) {
      logger.error('Failed to send password reset email:', error);
      throw new Error('Failed to send password reset email');
    }

    return {
      message: 'If the email exists, a password reset link has been sent.'
    };
  }

  /**
   * Reset password with token
   */
  static async resetPassword(token, newPassword) {
    const hashedToken = crypto
      .createHash('sha256')
      .update(token)
      .digest('hex');

    const resetToken = await PasswordResetToken.findOne({
      where: {
        token: hashedToken,
        used: false
      },
      include: [{ model: User, as: 'user' }]
    });

    if (!resetToken) {
      throw new Error('Invalid or expired reset token');
    }

    if (new Date() > resetToken.expires_at) {
      throw new Error('Reset token has expired');
    }

    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, 10);

    // Update user password
    await resetToken.user.update({
      password_hash: passwordHash,
      force_password_change: false
    });

    // Mark token as used
    await resetToken.update({ used: true });

    logger.info(`Password reset successful for user: ${resetToken.user.email}`);

    return {
      message: 'Password has been reset successfully'
    };
  }

  /**
   * Change password for authenticated user
   */
  static async changePassword(userId, currentPassword, newPassword) {
    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error('User not found');
    }

    // Superadmin with DEMO_SUPERADMIN lock — password can only be changed via backend/DB
    if (user.emp_code === 'DEMO_SUPERADMIN') {
      throw new Error('The superadmin password is locked and cannot be changed from the application. Contact the system owner to update it directly in the database.');
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isPasswordValid) {
      throw new Error('Current password is incorrect');
    }

    // Hash new password
    const passwordHash = await bcrypt.hash(newPassword, 10);

    // Update password
    await user.update({
      password_hash: passwordHash,
      force_password_change: false
    });

    logger.info(`Password changed for user: ${user.email}`);

    return {
      message: 'Password has been changed successfully'
    };
  }

  /**
   * Verify JWT token
   */
  static verifyToken(token) {
    try {
      return jwt.verify(token, config.jwt.secret);
    } catch (error) {
      throw new Error('Invalid token');
    }
  }
}

module.exports = AuthService;