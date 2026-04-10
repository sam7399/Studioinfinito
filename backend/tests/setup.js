// Test Setup - Configure test environment and database
const path = require('path');
const dotenv = require('dotenv');

// Load test environment variables
dotenv.config({ path: path.join(__dirname, '../.env.test') });

// Global test configuration
global.testConfig = {
  apiBaseUrl: process.env.TEST_API_URL || 'http://localhost:5000/api/v1',
  testDatabaseName: process.env.TEST_DB_NAME || 'task_manager_test',
  testTimeout: 30000
};

// Suppress logs during tests
if (process.env.SUPPRESS_LOGS === 'true') {
  global.console = {
    log: jest.fn(),
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn()
  };
}

// Clean up after tests
afterAll(async () => {
  // Close any open connections
  if (global.db && global.db.sequelize) {
    try {
      await global.db.sequelize.close();
    } catch (error) {
      console.error('Error closing database connection:', error);
    }
  }
});
