// Unit Tests for TaskService
const TaskService = require('../../../src/services/taskService');
const { Task, TaskActivity, User } = require('../../../src/models');
const NotificationService = require('../../../src/services/notificationService');
const PerformanceService = require('../../../src/services/performanceService');
const { getTask } = require('../../fixtures/tasks.fixture');
const { USERS } = require('../../fixtures/users.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/services/notificationService');
jest.mock('../../../src/services/performanceService');
jest.mock('../../../src/mail/mailer');
jest.mock('../../../src/utils/logger');

describe('TaskService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createTask', () => {
    it('should successfully create a new task', async () => {
      const taskData = {
        title: 'New Task',
        description: 'Task description',
        assigned_to: USERS.employee1.id,
        target_date: new Date(),
        priority: 'high'
      };

      const mockTask = {
        id: 1,
        ...taskData,
        created_by: USERS.management.id,
        status: 'pending',
        toJSON: jest.fn().mockReturnValue({ id: 1, ...taskData })
      };

      Task.create.mockResolvedValue(mockTask);
      NotificationService.notifyTaskAssigned.mockResolvedValue({});

      const result = await TaskService.createTask(taskData, USERS.management.id);

      expect(Task.create).toHaveBeenCalledWith(
        expect.objectContaining({
          title: taskData.title,
          created_by: USERS.management.id
        })
      );
    });

    it('should throw error for missing required fields', async () => {
      const invalidData = {
        description: 'Task without title'
      };

      Task.create.mockRejectedValue(new Error('Title is required'));

      await expect(TaskService.createTask(invalidData, USERS.management.id)).rejects.toThrow();
    });
  });

  describe('updateTask', () => {
    it('should successfully update task', async () => {
      const taskId = 1;
      const updateData = {
        title: 'Updated Title',
        status: 'in_progress'
      };

      const mockTask = {
        id: taskId,
        title: 'Original Title',
        status: 'pending',
        assigned_to: USERS.employee1.id,
        update: jest.fn().mockResolvedValue({ id: taskId, ...updateData }),
        toJSON: jest.fn().mockReturnValue({ id: taskId, ...updateData })
      };

      Task.findByPk.mockResolvedValue(mockTask);

      const result = await TaskService.updateTask(taskId, updateData);

      expect(mockTask.update).toHaveBeenCalledWith(updateData);
    });

    it('should throw error for non-existent task', async () => {
      Task.findByPk.mockResolvedValue(null);

      await expect(TaskService.updateTask(999, {})).rejects.toThrow();
    });
  });

  describe('completeTask', () => {
    it('should successfully complete task', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        status: 'in_progress',
        assigned_to: USERS.employee1.id,
        update: jest.fn().mockResolvedValue({ id: taskId, status: 'completed' }),
        toJSON: jest.fn().mockReturnValue({ id: taskId, status: 'completed' })
      };

      Task.findByPk.mockResolvedValue(mockTask);
      TaskActivity.create.mockResolvedValue({});

      const result = await TaskService.completeTask(taskId);

      expect(mockTask.update).toHaveBeenCalledWith({ status: 'completed' });
      expect(TaskActivity.create).toHaveBeenCalled();
    });

    it('should throw error when completing already completed task', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        status: 'completed'
      };

      Task.findByPk.mockResolvedValue(mockTask);

      await expect(TaskService.completeTask(taskId)).rejects.toThrow();
    });
  });

  describe('getTaskById', () => {
    it('should retrieve task with all associations', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        title: 'Test Task',
        creator: { id: 1, name: 'Creator' },
        assignee: { id: 2, name: 'Assignee' },
        activities: []
      };

      Task.findByPk.mockResolvedValue(mockTask);

      const result = await TaskService.getTaskById(taskId);

      expect(Task.findByPk).toHaveBeenCalledWith(
        taskId,
        expect.objectContaining({
          include: expect.any(Array)
        })
      );
    });

    it('should return null for non-existent task', async () => {
      Task.findByPk.mockResolvedValue(null);

      const result = await TaskService.getTaskById(999);

      expect(result).toBeNull();
    });
  });

  describe('deleteTask', () => {
    it('should successfully delete task', async () => {
      const taskId = 1;
      const mockTask = {
        id: taskId,
        destroy: jest.fn().mockResolvedValue(true)
      };

      Task.findByPk.mockResolvedValue(mockTask);

      await TaskService.deleteTask(taskId);

      expect(mockTask.destroy).toHaveBeenCalled();
    });

    it('should throw error when deleting non-existent task', async () => {
      Task.findByPk.mockResolvedValue(null);

      await expect(TaskService.deleteTask(999)).rejects.toThrow();
    });
  });
});
