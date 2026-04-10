// Unit Tests for ApprovalService
const ApprovalService = require('../../../src/services/approvalService');
const { Task, TaskApproval, TaskActivity } = require('../../../src/models');
const NotificationService = require('../../../src/services/notificationService');
const RBACService = require('../../../src/services/rbacService');
const { USERS } = require('../../fixtures/users.fixture');
const { getTask } = require('../../fixtures/tasks.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/services/notificationService');
jest.mock('../../../src/services/rbacService');
jest.mock('../../../src/utils/logger');

describe('ApprovalService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('submitForApproval', () => {
    it('should submit task for approval', async () => {
      const taskId = 1;
      const userId = USERS.employee1.id;
      const mockTask = {
        id: taskId,
        created_by: userId,
        assigned_to: userId,
        status: 'completed',
        approval_status: null,
        department_id: 1,
        update: jest.fn().mockResolvedValue({}),
        toJSON: jest.fn().mockReturnValue({})
      };

      Task.findByPk.mockResolvedValue(mockTask);
      RBACService.hasPermission.mockResolvedValue(true);
      TaskApproval.create.mockResolvedValue({ id: 1 });
      TaskActivity.create.mockResolvedValue({});
      NotificationService.notifyTaskSubmittedForApproval.mockResolvedValue({});

      const result = await ApprovalService.submitForApproval(taskId, userId);

      expect(Task.findByPk).toHaveBeenCalledWith(taskId);
      expect(mockTask.update).toHaveBeenCalled();
      expect(TaskApproval.create).toHaveBeenCalled();
    });

    it('should throw error for non-existent task', async () => {
      Task.findByPk.mockResolvedValue(null);

      await expect(ApprovalService.submitForApproval(999, USERS.employee1.id)).rejects.toThrow();
    });
  });

  describe('approveTask', () => {
    it('should approve task', async () => {
      const taskId = 1;
      const approverId = USERS.manager.id;
      const mockTask = {
        id: taskId,
        approval_status: 'pending',
        update: jest.fn().mockResolvedValue({}),
        toJSON: jest.fn().mockReturnValue({})
      };

      Task.findByPk.mockResolvedValue(mockTask);
      TaskApproval.findOne.mockResolvedValue({ id: 1 });
      RBACService.hasPermission.mockResolvedValue(true);
      TaskActivity.create.mockResolvedValue({});
      NotificationService.notifyTaskApproved.mockResolvedValue({});

      const result = await ApprovalService.approveTask(taskId, approverId, 'Looks good');

      expect(mockTask.update).toHaveBeenCalledWith(
        expect.objectContaining({
          approval_status: 'approved',
          approver_id: approverId
        })
      );
    });

    it('should throw error for non-pending task', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        approval_status: 'approved'
      };

      Task.findByPk.mockResolvedValue(mockTask);

      await expect(ApprovalService.approveTask(taskId, USERS.manager.id)).rejects.toThrow();
    });
  });

  describe('rejectTask', () => {
    it('should reject task with reason', async () => {
      const taskId = 1;
      const approverId = USERS.manager.id;
      const rejectionReason = 'Needs more details';

      const mockTask = {
        id: taskId,
        approval_status: 'pending',
        status: 'submitted_for_review',
        update: jest.fn().mockResolvedValue({}),
        toJSON: jest.fn().mockReturnValue({})
      };

      Task.findByPk.mockResolvedValue(mockTask);
      TaskApproval.findOne.mockResolvedValue({ id: 1 });
      RBACService.hasPermission.mockResolvedValue(true);
      TaskActivity.create.mockResolvedValue({});
      NotificationService.notifyTaskRejected.mockResolvedValue({});

      await ApprovalService.rejectTask(taskId, approverId, rejectionReason);

      expect(mockTask.update).toHaveBeenCalledWith(
        expect.objectContaining({
          approval_status: 'rejected',
          rejection_reason: rejectionReason,
          status: 'in_progress'
        })
      );
    });

    it('should throw error if no rejection reason provided', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        approval_status: 'pending'
      };

      Task.findByPk.mockResolvedValue(mockTask);

      await expect(ApprovalService.rejectTask(taskId, USERS.manager.id, '')).rejects.toThrow();
    });
  });

  describe('getTasksForApproval', () => {
    it('should retrieve pending tasks for manager', async () => {
      const managerId = USERS.manager.id;
      const mockTasks = [
        {
          id: 1,
          title: 'Task 1',
          approval_status: 'pending'
        },
        {
          id: 2,
          title: 'Task 2',
          approval_status: 'pending'
        }
      ];

      Task.findAll.mockResolvedValue(mockTasks);

      const result = await ApprovalService.getTasksForApproval(managerId, { limit: 10, offset: 0 });

      expect(Task.findAll).toHaveBeenCalled();
    });
  });

  describe('getApprovalHistory', () => {
    it('should retrieve approval history for task', async () => {
      const taskId = 1;
      const mockHistory = [
        {
          id: 1,
          status: 'pending',
          submitted_at: new Date()
        },
        {
          id: 2,
          status: 'approved',
          reviewed_at: new Date()
        }
      ];

      TaskApproval.findAll.mockResolvedValue(mockHistory);

      const result = await ApprovalService.getApprovalHistory(taskId);

      expect(TaskApproval.findAll).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { task_id: taskId }
        })
      );
    });
  });
});
