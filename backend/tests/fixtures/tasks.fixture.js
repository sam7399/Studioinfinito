// Test Fixtures for Tasks

const TASKS = {
  simple: {
    id: 1,
    title: 'Simple Task',
    description: 'A simple test task',
    created_by: 1,
    assigned_to: 5,
    status: 'pending',
    priority: 'low',
    target_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: null,
    created_at: new Date(),
    updated_at: new Date()
  },
  inProgress: {
    id: 2,
    title: 'Task In Progress',
    description: 'A task currently being worked on',
    created_by: 1,
    assigned_to: 5,
    status: 'in_progress',
    priority: 'medium',
    target_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: null,
    created_at: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
    updated_at: new Date()
  },
  completed: {
    id: 3,
    title: 'Completed Task',
    description: 'A completed test task',
    created_by: 1,
    assigned_to: 5,
    status: 'completed',
    priority: 'high',
    target_date: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: null,
    created_at: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
    updated_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
  },
  pendingApproval: {
    id: 4,
    title: 'Task Pending Approval',
    description: 'A task waiting for manager approval',
    created_by: 5,
    assigned_to: 5,
    status: 'submitted_for_review',
    priority: 'high',
    target_date: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: 'pending',
    approver_id: 4,
    created_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
    updated_at: new Date()
  },
  approved: {
    id: 5,
    title: 'Approved Task',
    description: 'A task that has been approved',
    created_by: 5,
    assigned_to: 5,
    status: 'submitted_for_review',
    priority: 'medium',
    target_date: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: 'approved',
    approver_id: 4,
    approval_date: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000),
    created_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
    updated_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
  },
  rejected: {
    id: 6,
    title: 'Rejected Task',
    description: 'A task that was rejected',
    created_by: 5,
    assigned_to: 5,
    status: 'in_progress',
    priority: 'high',
    target_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    department_id: 1,
    approval_status: 'rejected',
    approver_id: 4,
    rejection_reason: 'Needs more detail in description',
    created_at: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
    updated_at: new Date()
  }
};

/**
 * Create a task with overrides
 * @param {string} taskKey - Key from TASKS object
 * @param {Object} overrides - Override default values
 * @returns {Object}
 */
function getTask(taskKey, overrides = {}) {
  if (!TASKS[taskKey]) {
    throw new Error(`Task fixture '${taskKey}' not found`);
  }

  return {
    ...TASKS[taskKey],
    ...overrides
  };
}

/**
 * Get all test tasks
 * @returns {Array}
 */
function getAllTasks() {
  return Object.values(TASKS);
}

module.exports = {
  TASKS,
  getTask,
  getAllTasks
};
