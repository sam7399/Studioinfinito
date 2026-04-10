# Comprehensive Testing Guide - Studioinfinito

This guide provides instructions for running, maintaining, and expanding the test suite for the Studioinfinito task management system.

## Table of Contents

1. [Setup & Prerequisites](#setup--prerequisites)
2. [Running Tests](#running-tests)
3. [Understanding Test Structure](#understanding-test-structure)
4. [Writing New Tests](#writing-new-tests)
5. [Coverage Reports](#coverage-reports)
6. [Continuous Integration](#continuous-integration)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Setup & Prerequisites

### Install Testing Dependencies

All testing dependencies should already be installed via `npm install`. If not, install them:

```bash
cd backend
npm install --save-dev jest supertest
```

### Configuration Files

The following test configuration files exist:

- **jest.config.js** - Jest configuration
- **.env.test** - Test environment variables
- **tests/setup.js** - Global test setup and teardown

### Environment Setup

Ensure the test environment is configured:

```bash
# Copy test environment file
cp backend/.env.test backend/.env.test.local

# Update database credentials if needed
# TEST_DB_NAME: Database name for tests (default: task_manager_test)
# DBHOST: MySQL host (default: localhost)
# DBUSER: MySQL user (default: root)
# DBPASS: MySQL password
```

### Database Setup for Tests

Create a separate test database:

```bash
# MySQL command line
mysql -u root
CREATE DATABASE IF NOT EXISTS task_manager_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

## Running Tests

### Run All Tests

```bash
cd backend
npm test
```

### Run Specific Test Suite

```bash
# Unit tests only
npm test -- tests/unit/

# Integration tests only
npm test -- tests/integration/

# Security tests only
npm test -- tests/security/

# API endpoint tests only
npm test -- tests/api/
```

### Run Specific Test File

```bash
# Test a specific service
npm test -- tests/unit/services/authService.test.js

# Test a specific workflow
npm test -- tests/integration/task.integration.test.js
```

### Watch Mode (Development)

Run tests in watch mode for continuous testing during development:

```bash
npm run test:watch
```

This watches for file changes and automatically re-runs related tests.

### Run with Coverage

```bash
npm test -- --coverage
```

## Understanding Test Structure

### Test Directory Organization

```
tests/
├── setup.js                 # Global test setup
├── fixtures/                # Test data fixtures
│   ├── users.fixture.js     # User test data
│   └── tasks.fixture.js     # Task test data
├── utils/                   # Test utilities
│   ├── testHelper.js        # Helper functions
│   └── database.js          # Database utilities
├── unit/                    # Unit tests
│   └── services/            # Service tests
│       ├── authService.test.js
│       ├── taskService.test.js
│       ├── notificationService.test.js
│       ├── approvalService.test.js
│       └── performanceService.test.js
├── integration/             # Integration tests
│   ├── auth.integration.test.js
│   ├── task.integration.test.js
│   ├── approval.integration.test.js
│   └── notification.integration.test.js
├── api/                     # API endpoint tests
│   └── endpoints.test.js    # All endpoint tests
└── security/                # Security tests
    └── security.test.js     # Security-focused tests
```

### Test File Naming Convention

- Unit tests: `{file}.test.js`
- Integration tests: `{workflow}.integration.test.js`
- Security tests: `security.test.js` or `{module}.security.test.js`

## Writing New Tests

### Basic Unit Test Template

```javascript
const ServiceName = require('../../../src/services/serviceName');
const { Model } = require('../../../src/models');
const { USERS } = require('../../fixtures/users.fixture');

jest.mock('../../../src/models');
jest.mock('../../../src/utils/logger');

describe('ServiceName', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('methodName', () => {
    it('should describe expected behavior', async () => {
      // Arrange - Setup test data
      const testData = { /* ... */ };

      // Act - Execute the method
      const result = await ServiceName.methodName(testData);

      // Assert - Verify results
      expect(result).toBeDefined();
      expect(Model.create).toHaveBeenCalled();
    });
  });
});
```

### Using Test Fixtures

```javascript
const { USERS, getUserWithHash } = require('../../fixtures/users.fixture');
const { getTask } = require('../../fixtures/tasks.fixture');

// Use predefined user
const user = USERS.employee1;

// Get user with hashed password
const userWithHash = await getUserWithHash('employee1');

// Get task with overrides
const task = getTask('simple', { title: 'Custom Title' });
```

### Using Test Helpers

```javascript
const {
  createTestToken,
  createTestUser,
  createTestTask,
  authenticatedRequest,
  hashPassword,
  verifyPassword,
  wait
} = require('../../utils/testHelper');

// Create test token
const token = createTestToken({ id: 1, role: 'employee' });

// Create test user
const user = createTestUser({ role: 'manager' });

// Make authenticated API request
const response = await authenticatedRequest(app, 'get', '/api/v1/tasks', user);
```

### Mocking Models

```javascript
jest.mock('../../../src/models');
const { User, Task } = require('../../../src/models');

// Mock findOne
User.findOne.mockResolvedValue({
  id: 1,
  email: 'test@example.com',
  toJSON: jest.fn().mockReturnValue({ /* ... */ })
});

// Mock create
Task.create.mockResolvedValue({
  id: 1,
  title: 'Test Task'
});

// Mock update
Task.prototype.update.mockResolvedValue({ /* ... */ });
```

## Coverage Reports

### Generate Coverage Report

```bash
cd backend
npm test -- --coverage
```

This generates a coverage report in the `coverage/` directory.

### View Coverage Report

```bash
# Open HTML coverage report
open coverage/lcov-report/index.html
```

### Coverage Targets

The testing suite targets:

- **Overall Coverage**: 60%+
- **Services Coverage**: 70%+ (critical business logic)
- **Controllers Coverage**: 50%+
- **Utilities Coverage**: 80%+

### Coverage Badge

For CI/CD pipelines, generate badge:

```bash
cat coverage/coverage-summary.json | jq '.total.lines.pct'
```

## Continuous Integration

### GitHub Actions

Tests automatically run on every push via `.github/workflows/tests.yml`

### Local Pre-commit Testing

```bash
# Install husky for git hooks
npm install husky --save-dev

# Enable pre-commit hook
npx husky install

# Create pre-commit hook
echo '#!/bin/sh' > .husky/pre-commit
echo 'npm test' >> .husky/pre-commit
chmod +x .husky/pre-commit
```

## Best Practices

### 1. Test Organization

- **One responsibility per test**: Each test should verify one behavior
- **Clear test names**: Use descriptive names that explain what is being tested
- **Arrange-Act-Assert**: Follow AAA pattern for clarity

### 2. Mocking

- **Mock external dependencies**: Database, email, logger
- **Keep mocks simple**: Only mock what's necessary
- **Use real implementations for core logic**: Test actual behavior

### 3. Test Data

- **Use fixtures**: Reuse consistent test data
- **Isolate tests**: Don't share state between tests
- **Clean up**: Use beforeEach/afterEach for setup/teardown

### 4. Async Testing

```javascript
// Always return or await promises
it('should handle async operations', async () => {
  const result = await asyncFunction();
  expect(result).toBeDefined();
});

// Use jest.useFakeTimers() for time-dependent code
it('should handle timeouts', () => {
  jest.useFakeTimers();
  // ...
  jest.runAllTimers();
  jest.useRealTimers();
});
```

### 5. Error Testing

```javascript
// Test both success and failure cases
it('should handle errors', async () => {
  Model.findOne.mockRejectedValue(new Error('Database error'));
  await expect(service.method()).rejects.toThrow('Database error');
});
```

### 6. Coverage Maintenance

- Review coverage reports regularly
- Aim for 60%+ overall coverage
- Prioritize critical business logic
- Add tests for bug fixes

## Troubleshooting

### Tests Timeout

**Problem**: Tests taking too long to complete

**Solution**:
```javascript
// Increase timeout
jest.setTimeout(30000); // 30 seconds

// Or in jest.config.js
module.exports = {
  testTimeout: 30000
};
```

### Database Connection Errors

**Problem**: Cannot connect to test database

**Solution**:
```bash
# Verify MySQL is running
mysql -u root -p -e "SELECT 1;"

# Check .env.test
cat backend/.env.test

# Create test database if missing
mysql -u root -e "CREATE DATABASE task_manager_test;"
```

### Mock Not Working

**Problem**: Mock is not applied

**Solution**:
```javascript
// Clear mocks between tests
beforeEach(() => {
  jest.clearAllMocks();
});

// Mock before imports
jest.mock('../../../src/models');
const { Model } = require('../../../src/models');
```

### Flaky Tests

**Problem**: Tests fail intermittently

**Solution**:
- Increase timeout for async operations
- Use `jest.useFakeTimers()` for time-dependent code
- Avoid external API calls in tests
- Reset state properly in beforeEach

### Cannot Find Module

**Problem**: "Cannot find module" error

**Solution**:
```javascript
// Check module path
// Use absolute paths from backend directory
const Service = require('../../../src/services/serviceName');

// Or use jest moduleNameMapper
// In jest.config.js
moduleNameMapper: {
  '^@services/(.*)$': '<rootDir>/src/services/$1'
}
```

## Running Tests Locally

### Development Workflow

```bash
cd backend

# 1. Install dependencies
npm install

# 2. Setup test database
mysql -u root -e "CREATE DATABASE task_manager_test;"

# 3. Configure .env.test with your database credentials

# 4. Run tests
npm test

# 5. Watch for changes
npm run test:watch

# 6. Check coverage
npm test -- --coverage
```

### CI/CD Pipeline

```bash
# This runs automatically on every push
# See .github/workflows/tests.yml

# Manual trigger
git push origin feature-branch
```

## Additional Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest Documentation](https://github.com/visionmedia/supertest)
- [Testing Best Practices](https://javascript.info/testing)
- [Mock/Stub Patterns](https://github.com/goldbergyoni/javascript-testing-best-practices)

## Contact & Support

For testing-related questions or issues:

1. Review this guide
2. Check TEST_PROCEDURES.md for manual testing
3. Review existing test examples
4. Consult Jest and Supertest documentation
