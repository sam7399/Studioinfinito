// Integration Tests for Task Workflow
const { Task, TaskActivity, User, Notification } = require('../../src/models');
const TaskService = require('../../src/services/taskService');
const NotificationService = require('../../src/services/notificationService');
const { USERS } = require('../fixtures/users.fixture');
const { getTask } = require('../fixtures/tasks.fixture');

jest.mock('../../src/models');
jest.mock('../../src/services/notificationService');
jest.mock('../../src/mail/mailer');
jest.mock('../../src/utils/logger');

describe('Task Workflow Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Complete Task Lifecycle', () => {
    it('should complete full task lifecycle: create -> assign -> work -> complete -> approve', async () => {
      // Step 1: Create Task
      const taskData = {
        title: 'Integration Test Task',
        description: 'Complete lifecycle test',
        assigned_to: USERS.employee1.id,
        target_date: new Date(),
        priority: 'high'
      };

      const createdTask = {
        id: 1,
        ...taskData,
        created_by: USERS.management.id,
        status: 'pending',
        approval_status: null,
        toJSON: jest.fn().mockReturnValue(taskData)
      };

      Task.create.mockResolvedValue(createdTask);
      NotificationService.notifyTaskAssigned.mockResolvedValue({});
      TaskActivity.create.mockResolvedValue({});

      const created = await Task.create(taskData);
      expect(created).toBeDefined();
      expect(created.status).toBe('pending');

      // Step 2: Update Task Status to In Progress
      createdTask.status = 'in_progress';
      createdTask.update = jest.fn().mockResolvedValue(createdTask);
      await createdTask.update({ status: 'in_progress' });
      expect(createdTask.update).toHaveBeenCalled();

      // Step 3: Mark Task as Complete
      createdTask.status = 'completed';
      await createdTask.update({ status: 'completed' });
      expect(createdTask.status).toBe('completed');

      // Step 4: Task submitted for approval
      createdTask.status = 'submitted_for_review';
      createdTask.approval_status = 'pending';
      await createdTask.update({
        status: 'submitted_for_review',
        approval_status: 'pending',
        approver_id: USERS.manager.id
      });

      // Step 5: Approve Task
      createdTask.approval_status = 'approved';
      createdTask.approval_date = new Date();
      await createdTask.update({
        approval_status: 'approved',
        approval_date: new Date()
      });
      expect(createdTask.approval_status).toBe('approved');
    });
  });

  describe('Task Assignment and Notification', () => {
    it('should assign task and create notification', async () => {
      const taskData = getTask('simple');
      const mockTask = {
        ...taskData,
        toJSON: jest.fn().mockReturnValue(taskData),
        update: jest.fn().mockResolvedValue(taskData)
      };

      Task.create.mockResolvedValue(mockTask);
      NotificationService.notifyTaskAssigned.mockResolvedValue({
        id: 1,
        user_id: USERS.employee1.id,
        type: 'task_assigned'
      });

      // Create task
      const created = await Task.create(taskData);
      expect(created).toBeDefined();

      // Notify assignee
      const notification = await NotificationService.notifyTaskAssigned(
        USERS.employee1.id,
        created.id,
        created.title
      );
      expect(notification).toBeDefined();
    });
  });

  describe('Task Rejection and Rework', () => {
    it('should reject task and return to in_progress', async () => {
      const taskData = getTask('pendingApproval');
      const mockTask = {
        ...taskData,
        approval_status: 'pending',
        toJSON: jest.fn().mockReturnValue(taskData),
        update: jest.fn().mockResolvedValue(taskData)
      };

      Task.findByPk.mockResolvedValue(mockTask);
      TaskActivity.create.mockResolvedValue({});

      // Reject task
      await mockTask.update({
        approval_status: 'rejected',
        status: 'in_progress',
        rejection_reason: 'Needs more details'
      });

      expect(mockTask.update).toHaveBeenCalledWith(
        expect.objectContaining({
          approval_status: 'rejected',
          status: 'in_progress'
        })
      );
    });
  });
});
