const nodemailer = require('nodemailer');
const config = require('../config');
const logger = require('../utils/logger');
const fs = require('fs');
const path = require('path');

// Create transporter
const transporter = nodemailer.createTransport({
  host: config.email.host,
  port: config.email.port,
  secure: config.email.secure,
  auth: config.email.auth
});

// Verify transporter configuration
transporter.verify((error, success) => {
  if (error) {
    logger.error('Email transporter verification failed:', error);
  } else {
    logger.info('Email transporter is ready');
  }
});

// Load email templates
const loadTemplate = (templateName) => {
  const templatePath = path.join(__dirname, 'templates', `${templateName}.html`);
  return fs.readFileSync(templatePath, 'utf8');
};

// Replace placeholders in template
const replacePlaceholders = (template, data) => {
  let result = template;
  Object.keys(data).forEach(key => {
    const placeholder = new RegExp(`{{${key}}}`, 'g');
    result = result.replace(placeholder, data[key]);
  });
  return result;
};

class Mailer {
  static async sendMail(to, subject, html, attachments = []) {
    try {
      const info = await transporter.sendMail({
        from: config.email.from,
        to,
        subject,
        html,
        attachments
      });
      
      logger.info(`Email sent: ${info.messageId} to ${to}`);
      return info;
    } catch (error) {
      logger.error('Email send error:', error);
      throw error;
    }
  }

  static async sendTaskAssignment(toEmail, toName, task, assignerName) {
    try {
      const template = loadTemplate('assignment');
      const html = replacePlaceholders(template, {
        name: toName,
        assigner_name: assignerName,
        task_title: task.title,
        task_description: task.description || 'No description provided',
        task_priority: task.priority,
        task_due_date: task.due_date || 'Not set',
        task_url: `${config.urls.app}/tasks/${task.id}`,
        app_url: config.urls.app
      });

      await this.sendMail(
        toEmail,
        `New Task Assigned: ${task.title}`,
        html
      );
    } catch (error) {
      logger.error('Send task assignment email error:', error);
    }
  }

  static async sendTaskCompletion(toEmail, toName, task, completedByName) {
    try {
      const template = loadTemplate('completion');
      const html = replacePlaceholders(template, {
        name: toName,
        completed_by_name: completedByName,
        task_title: task.title,
        task_url: `${config.urls.app}/tasks/${task.id}`,
        app_url: config.urls.app
      });

      await this.sendMail(
        toEmail,
        `Task Completed - Review Required: ${task.title}`,
        html
      );
    } catch (error) {
      logger.error('Send task completion email error:', error);
    }
  }

  static async sendTaskReview(toEmail, toName, task, reviewerName, status, comment) {
    try {
      const template = loadTemplate('review');
      const statusText = status === 'approved' ? 'Approved' : 'Reopened';
      const html = replacePlaceholders(template, {
        name: toName,
        reviewer_name: reviewerName,
        task_title: task.title,
        review_status: statusText,
        review_comment: comment || 'No comment provided',
        task_url: `${config.urls.app}/tasks/${task.id}`,
        app_url: config.urls.app
      });

      await this.sendMail(
        toEmail,
        `Task ${statusText}: ${task.title}`,
        html
      );
    } catch (error) {
      logger.error('Send task review email error:', error);
    }
  }

  static async sendPasswordReset(toEmail, toName, resetUrl) {
    try {
      const template = loadTemplate('passwordReset');
      const html = replacePlaceholders(template, {
        name: toName,
        reset_url: resetUrl,
        app_url: config.urls.app
      });

      await this.sendMail(
        toEmail,
        'Password Reset Request',
        html
      );
    } catch (error) {
      logger.error('Send password reset email error:', error);
    }
  }

  static async sendReviewReminder(toEmail, toName, task) {
    try {
      const template = loadTemplate('completion'); // Reuse completion template
      const html = replacePlaceholders(template, {
        name: toName,
        completed_by_name: 'Team Member',
        task_title: task.title,
        task_url: `${config.urls.app}/tasks/${task.id}`,
        app_url: config.urls.app
      });

      await this.sendMail(
        toEmail,
        `Reminder: Task Pending Review - ${task.title}`,
        html
      );
    } catch (error) {
      logger.error('Send review reminder email error:', error);
    }
  }
}

module.exports = Mailer;