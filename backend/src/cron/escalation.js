'use strict';

const cron = require('node-cron');
const { Task, User, Department } = require('../models');
const { Op } = require('sequelize');
const mailer = require('../mail/mailer');
const logger = require('../utils/logger');

/**
 * Auto Escalation Cron — runs every hour
 *
 * Level 0 → 1 : After 24h overdue → notify Department Head
 * Level 1 → 2 : After 48h overdue → notify Management
 * Level 2 → 3 : After 72h overdue → mark Critical Delay
 */
const escalationJob = cron.schedule('30 * * * *', async () => {
  try {
    logger.info('Starting escalation job');

    const now = new Date();
    const h24 = new Date(now - 24 * 3600 * 1000);
    const h48 = new Date(now - 48 * 3600 * 1000);
    const h72 = new Date(now - 72 * 3600 * 1000);

    // Overdue, not finalized
    const overdueTasks = await Task.findAll({
      where: {
        status: { [Op.notIn]: ['finalized', 'cancelled'] },
        due_date: { [Op.lt]: now },
        escalation_level: { [Op.lt]: 3 }
      },
      include: [
        { association: 'assignee', attributes: ['id', 'name', 'email', 'department_id'] },
        { association: 'creator', attributes: ['id', 'name', 'email'] },
        { association: 'department', attributes: ['id', 'name'] }
      ]
    });

    for (const task of overdueTasks) {
      try {
        const overdueAt = new Date(task.due_date);
        const hoursOverdue = (now - overdueAt) / 3600000;

        // Level 0 → 1: 24h+ overdue
        if (task.escalation_level === 0 && hoursOverdue >= 24) {
          // Find department head
          if (task.department_id) {
            const deptHead = await User.findOne({
              where: {
                department_id: task.department_id,
                role: 'department_head',
                company_id: task.company_id
              },
              attributes: ['id', 'name', 'email']
            });

            if (deptHead) {
              await mailer.sendMail(
                deptHead.email,
                `⚠️ Task Overdue (24h): ${task.title}`,
                `<p>Dear ${deptHead.name},</p>
                 <p>The following task is <strong>24+ hours overdue</strong>:</p>
                 <p><strong>${task.title}</strong><br>
                 Assigned to: ${task.assignee?.name || 'N/A'}<br>
                 Department: ${task.department?.name || 'N/A'}<br>
                 Due Date: ${task.due_date}</p>
                 <p>Please follow up immediately.</p>`
              );
              logger.info(`Escalation L1 sent for task ${task.id} to dept head ${deptHead.email}`);
            }
          }

          await task.update({ escalation_level: 1, last_escalation_at: now });

        // Level 1 → 2: 48h+ overdue
        } else if (task.escalation_level === 1 && hoursOverdue >= 48) {
          // Notify management
          const managers = await User.findAll({
            where: {
              company_id: task.company_id,
              role: { [Op.in]: ['management', 'superadmin'] }
            },
            attributes: ['id', 'name', 'email']
          });

          for (const mgr of managers) {
            await mailer.sendMail(
              mgr.email,
              `🚨 Task Overdue (48h): ${task.title}`,
              `<p>Dear ${mgr.name},</p>
               <p>This task is <strong>48+ hours overdue</strong> and requires your attention:</p>
               <p><strong>${task.title}</strong><br>
               Assigned to: ${task.assignee?.name || 'N/A'}<br>
               Department: ${task.department?.name || 'N/A'}<br>
               Due Date: ${task.due_date}</p>
               <p>Immediate action required.</p>`
            );
          }
          logger.info(`Escalation L2 sent for task ${task.id} to management`);
          await task.update({ escalation_level: 2, last_escalation_at: now });

        // Level 2 → 3: 72h+ overdue — mark Critical Delay
        } else if (task.escalation_level === 2 && hoursOverdue >= 72) {
          await task.update({
            escalation_level: 3,
            last_escalation_at: now,
            priority: 'urgent'
          });

          // Notify all: creator + assignee + management
          const notifyEmails = new Set();
          if (task.creator?.email) notifyEmails.add(task.creator.email);
          if (task.assignee?.email) notifyEmails.add(task.assignee.email);

          const topMgmt = await User.findAll({
            where: { company_id: task.company_id, role: { [Op.in]: ['management', 'superadmin'] } },
            attributes: ['email']
          });
          topMgmt.forEach(m => notifyEmails.add(m.email));

          for (const email of notifyEmails) {
            await mailer.sendMail(
              email,
              `🔴 CRITICAL DELAY (72h): ${task.title}`,
              `<p>Task <strong>${task.title}</strong> is now marked as <strong>CRITICAL DELAY</strong> (72+ hours overdue).<br>
               Priority has been escalated to URGENT.<br>
               Due Date: ${task.due_date}<br>
               Assigned to: ${task.assignee?.name || 'N/A'}</p>
               <p>Immediate escalation required.</p>`
            );
          }
          logger.info(`Escalation L3 (Critical) set for task ${task.id}`);
        }
      } catch (err) {
        logger.error(`Escalation error for task ${task.id}:`, err);
      }
    }

    logger.info(`Escalation job done — processed ${overdueTasks.length} tasks`);
  } catch (err) {
    logger.error('Escalation job failed:', err);
  }
}, { scheduled: false });

module.exports = escalationJob;
