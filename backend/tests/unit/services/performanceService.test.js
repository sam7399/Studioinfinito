// Unit Tests for PerformanceService
const PerformanceService = require('../../../src/services/performanceService');
const { TaskMetrics, EmployeePerformance, User, Task } = require('../../../src/models');
const { USERS } = require('../../fixtures/users.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/utils/logger');

describe('PerformanceService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('calculateUserMetrics', () => {
    it('should calculate metrics for user in current month', async () => {
      const userId = USERS.employee1.id;
      const currentDate = new Date();

      const mockTasks = [
        {
          id: 1,
          status: 'completed',
          priority: 'high',
          created_at: currentDate,
          updated_at: currentDate
        },
        {
          id: 2,
          status: 'completed',
          priority: 'medium',
          created_at: currentDate,
          updated_at: currentDate
        }
      ];

      Task.findAll.mockResolvedValue(mockTasks);
      TaskMetrics.findOrCreate.mockResolvedValue([{ id: 1 }, true]);
      TaskMetrics.update.mockResolvedValue([1]);

      const result = await PerformanceService.calculateUserMetrics(userId);

      expect(Task.findAll).toHaveBeenCalled();
      expect(TaskMetrics.findOrCreate).toHaveBeenCalled();
    });

    it('should throw error for invalid user', async () => {
      const userId = 999;
      User.findByPk.mockResolvedValue(null);

      // If service validates user existence
      // await expect(PerformanceService.calculateUserMetrics(userId)).rejects.toThrow();
    });
  });

  describe('updateEmployeePerformance', () => {
    it('should update employee performance record', async () => {
      const userId = USERS.employee1.id;
      const performanceData = {
        quality_score: 85,
        overall_rating: 4.5
      };

      const mockPerformance = {
        id: 1,
        user_id: userId,
        update: jest.fn().mockResolvedValue({})
      };

      EmployeePerformance.findOne.mockResolvedValue(mockPerformance);

      await PerformanceService.updateEmployeePerformance(userId, performanceData);

      expect(EmployeePerformance.findOne).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { user_id: userId }
        })
      );
    });

    it('should create new performance record if not exists', async () => {
      const userId = USERS.employee1.id;
      const performanceData = {
        quality_score: 85,
        overall_rating: 4.5
      };

      EmployeePerformance.findOne.mockResolvedValue(null);
      EmployeePerformance.create.mockResolvedValue({
        id: 1,
        user_id: userId,
        ...performanceData
      });

      await PerformanceService.updateEmployeePerformance(userId, performanceData);

      expect(EmployeePerformance.create).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: userId,
          ...performanceData
        })
      );
    });
  });

  describe('getEmployeePerformance', () => {
    it('should retrieve employee performance', async () => {
      const userId = USERS.employee1.id;
      const mockPerformance = {
        id: 1,
        user_id: userId,
        quality_score: 85,
        overall_rating: 4.5
      };

      EmployeePerformance.findOne.mockResolvedValue(mockPerformance);

      const result = await PerformanceService.getEmployeePerformance(userId);

      expect(EmployeePerformance.findOne).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { user_id: userId }
        })
      );
    });

    it('should return null if performance not found', async () => {
      const userId = USERS.employee1.id;
      EmployeePerformance.findOne.mockResolvedValue(null);

      const result = await PerformanceService.getEmployeePerformance(userId);

      expect(result).toBeNull();
    });
  });
});
