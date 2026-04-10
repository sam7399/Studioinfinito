// Unit Tests for NotificationService
const NotificationService = require('../../../src/services/notificationService');
const { Notification, NotificationPreference } = require('../../../src/models');
const { USERS } = require('../../fixtures/users.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/utils/logger');

describe('NotificationService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createNotification', () => {
    it('should create notification for user', async () => {
      const notificationData = {
        user_id: USERS.employee1.id,
        task_id: 1,
        type: 'task_assigned',
        title: 'Task Assigned',
        description: 'You have been assigned a new task',
        metadata: { task_id: 1 }
      };

      const mockNotification = {
        id: 1,
        ...notificationData
      };

      Notification.create.mockResolvedValue(mockNotification);

      const result = await NotificationService.createNotification(notificationData);

      expect(Notification.create).toHaveBeenCalledWith(notificationData);
    });

    it('should throw error for missing required fields', async () => {
      const invalidData = {
        type: 'task_assigned'
        // missing user_id
      };

      Notification.create.mockRejectedValue(new Error('user_id is required'));

      await expect(NotificationService.createNotification(invalidData)).rejects.toThrow();
    });
  });

  describe('getUserNotifications', () => {
    it('should retrieve paginated notifications for user', async () => {
      const userId = USERS.employee1.id;
      const mockNotifications = [
        {
          id: 1,
          user_id: userId,
          type: 'task_assigned',
          read: false
        },
        {
          id: 2,
          user_id: userId,
          type: 'task_completed',
          read: false
        }
      ];

      Notification.findAll.mockResolvedValue(mockNotifications);

      const result = await NotificationService.getUserNotifications(userId, { limit: 10, offset: 0 });

      expect(Notification.findAll).toHaveBeenCalled();
    });

    it('should return empty array if no notifications', async () => {
      const userId = USERS.employee1.id;
      Notification.findAll.mockResolvedValue([]);

      const result = await NotificationService.getUserNotifications(userId);

      expect(result).toEqual([]);
    });
  });

  describe('markAsRead', () => {
    it('should mark notification as read', async () => {
      const notificationId = 1;
      const mockNotification = {
        id: notificationId,
        read: false,
        update: jest.fn().mockResolvedValue({ id: notificationId, read: true })
      };

      Notification.findByPk.mockResolvedValue(mockNotification);

      const result = await NotificationService.markAsRead(notificationId);

      expect(mockNotification.update).toHaveBeenCalledWith({
        read: true,
        read_at: expect.any(Date)
      });
    });

    it('should throw error for non-existent notification', async () => {
      Notification.findByPk.mockResolvedValue(null);

      await expect(NotificationService.markAsRead(999)).rejects.toThrow();
    });
  });

  describe('getUnreadCount', () => {
    it('should return unread notification count', async () => {
      const userId = USERS.employee1.id;
      Notification.count.mockResolvedValue(5);

      const result = await NotificationService.getUnreadCount(userId);

      expect(result).toBe(5);
      expect(Notification.count).toHaveBeenCalledWith({
        where: { user_id: userId, read: false }
      });
    });

    it('should return 0 if no unread notifications', async () => {
      const userId = USERS.employee1.id;
      Notification.count.mockResolvedValue(0);

      const result = await NotificationService.getUnreadCount(userId);

      expect(result).toBe(0);
    });
  });

  describe('notifyTaskAssigned', () => {
    it('should create notification when task is assigned', async () => {
      const assigneeId = USERS.employee1.id;
      const taskId = 1;

      Notification.create.mockResolvedValue({
        id: 1,
        user_id: assigneeId,
        task_id: taskId,
        type: 'task_assigned'
      });

      const result = await NotificationService.notifyTaskAssigned(assigneeId, taskId, 'Test Task');

      expect(Notification.create).toHaveBeenCalled();
    });
  });
});
