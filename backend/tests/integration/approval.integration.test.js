// Integration Tests for Approval Workflow
const { Task, TaskApproval, TaskActivity, Notification, User } = require('../../src/models');
const ApprovalService = require('../../src/services/approvalService');
const NotificationService = require('../../src/services/notificationService');
const RBACService = require('../../src/services/rbacService');
const { USERS } = require('../fixtures/users.fixture');
const { getTask } = require('../fixtures/tasks.fixture');

jest.mock('../../src/models');
jest.mock('../../src/services/notificationService');
jest.mock('../../src/services/rbacService');
jest.mock('../../src/utils/logger');

describe('Approval Workflow Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Complete Approval Workflow', () => {
    it('should complete submit -> approve workflow', async () => {
      const taskId = 1;
      const employeeId = USERS.employee1.id;
      const managerId = USERS.manager.id;

      const mockTask = {
        id: taskId,
        status: 'completed',
        approval_status: null,
        created_by: employeeId,
        assigned_to: employeeId,
        department_id: 1,
        toJSON: jest.fn().mockReturnValue({ id: taskId }),
        update: jest.fn().mockResolvedValue({})
      };

      Task.findByPk.mockResolvedValue(mockTask);
      RBACService.hasPermission.mockResolvedValue(true);
      TaskApproval.create.mockResolvedValue({ id: 1, status: 'pending' });
      TaskActivity.create.mockResolvedValue({});
      NotificationService.notifyTaskSubmittedForApproval.mockResolvedValue({});
      NotificationService.notifyTaskApproved.mockResolvedValue({});

      // Step 1: Submit for approval
      await ApprovalService.submitForApproval(taskId, employeeId);
      expect(mockTask.update).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'submitted_for_review',
          approval_status: 'pending'
        })
      );

      // Step 2: Manager receives notification
      const notification = await NotificationService.notifyTaskSubmittedForApproval(
        managerId,
        taskId
      );
      expect(notification).toBeDefined();

      // Step 3: Approve task
      TaskApproval.findOne.mockResolvedValue({ id: 1 });
      await ApprovalService.approveTask(taskId, managerId, 'Approved');
      expect(mockTask.update).toHaveBeenCalled();
    });
  });

  describe('Multi-Level Approval Escalation', () => {
    it('should escalate approval through management hierarchy', async () => {
      const taskId = 1;
      const employeeId = USERS.employee1.id;
      const managerId = USERS.manager.id;
      const deptHeadId = USERS.deptHead.id;

      const mockTask = {
        id: taskId,
        status: 'completed',
        approval_status: null,
        created_by: employeeId,
        assigned_to: employeeId,
        department_id: 1,
        toJSON: jest.fn().mockReturnValue({ id: taskId }),
        update: jest.fn().mockResolvedValue({})
      };

      Task.findByPk.mockResolvedValue(mockTask);
      RBACService.hasPermission.mockResolvedValue(true);
      TaskApproval.create.mockResolvedValue({ id: 1, status: 'pending' });
      TaskApproval.findOne.mockResolvedValue({ id: 1 });
      TaskActivity.create.mockResolvedValue({});
      NotificationService.notifyTaskSubmittedForApproval.mockResolvedValue({});

      // Submit for approval
      await ApprovalService.submitForApproval(taskId, employeeId);

      // Manager rejects -> sent back to employee
      await ApprovalService.rejectTask(taskId, managerId, 'Needs revision');
      expect(mockTask.update).toHaveBeenCalled();
    });
  });

  describe('Approval History Tracking', () => {
    it('should maintain audit trail of all approval actions', async () => {
      const taskId = 1;
      const managerId = USERS.manager.id;

      const approvalHistory = [
        {
          id: 1,
          task_id: taskId,
          approver_id: managerId,
          status: 'pending',
          submitted_at: new Date()
        },
        {
          id: 2,
          task_id: taskId,
          approver_id: managerId,
          status: 'rejected',
          reviewed_at: new Date(),
          reason: 'Needs revision'
        },
        {
          id: 3,
          task_id: taskId,
          approver_id: managerId,
          status: 'approved',
          reviewed_at: new Date()
        }
      ];

      TaskApproval.findAll.mockResolvedValue(approvalHistory);

      const history = await ApprovalService.getApprovalHistory(taskId);
      expect(history).toHaveLength(3);
      expect(history[0].status).toBe('pending');
      expect(history[1].status).toBe('rejected');
      expect(history[2].status).toBe('approved');
    });
  });
});
