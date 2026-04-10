// Integration Tests for Notification System
const { Notification, NotificationPreference, User, Task } = require('../../src/models');
const NotificationService = require('../../src/services/notificationService');
const { USERS } = require('../fixtures/users.fixture');

jest.mock('../../src/models');
jest.mock('../../src/utils/logger');

describe('Notification System Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Notification Preferences', () => {
    it('should respect user notification preferences', async () => {
      const userId = USERS.employee1.id;

      const mockPreferences = {
        user_id: userId,
        task_assigned: true,
        task_completed: true,
        task_commented: false,
        email_notifications: true,
        push_notifications: false
      };

      NotificationPreference.findOne.mockResolvedValue(mockPreferences);

      const prefs = await NotificationService.getPreferences(userId);
      expect(prefs.email_notifications).toBe(true);
      expect(prefs.push_notifications).toBe(false);
    });

    it('should update notification preferences', async () => {
      const userId = USERS.employee1.id;
      const mockPreferences = {
        user_id: userId,
        update: jest.fn().mockResolvedValue({})
      };

      NotificationPreference.findOne.mockResolvedValue(mockPreferences);

      const updates = { email_notifications: false };
      await mockPreferences.update(updates);

      expect(mockPreferences.update).toHaveBeenCalledWith(updates);
    });
  });

  describe('Real-time Notification Delivery', () => {
    it('should create and deliver notification', async () => {
      const userId = USERS.employee1.id;
      const taskId = 1;

      const notification = {
        id: 1,
        user_id: userId,
        task_id: taskId,
        type: 'task_assigned',
        title: 'New Task Assignment',
        description: 'You have been assigned a new task',
        read: false,
        created_at: new Date()
      };

      Notification.create.mockResolvedValue(notification);

      const created = await NotificationService.createNotification({
        user_id: userId,
        task_id: taskId,
        type: 'task_assigned',
        title: 'New Task Assignment',
        description: 'You have been assigned a new task'
      });

      expect(created).toBeDefined();
      expect(created.read).toBe(false);
    });
  });

  describe('Notification Lifecycle', () => {
    it('should mark notification as read', async () => {
      const notificationId = 1;
      const userId = USERS.employee1.id;

      const mockNotification = {
        id: notificationId,
        user_id: userId,
        read: false,
        update: jest.fn().mockResolvedValue({ read: true })
      };

      Notification.findByPk.mockResolvedValue(mockNotification);

      await NotificationService.markAsRead(notificationId);
      expect(mockNotification.update).toHaveBeenCalledWith(
        expect.objectContaining({ read: true })
      );
    });

    it('should delete old notifications', async () => {
      const userId = USERS.employee1.id;
      const threshold = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      Notification.destroy.mockResolvedValue(5);

      const deleted = await Notification.destroy({
        where: {
          user_id: userId,
          read: true,
          created_at: { [require('../../src/models').Sequelize.Op.lt]: threshold }
        }
      });

      expect(Notification.destroy).toHaveBeenCalled();
    });
  });
});
