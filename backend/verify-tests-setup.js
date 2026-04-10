#!/usr/bin/env node

/**
 * Comprehensive Testing Setup Verification Script
 * Checks that all testing infrastructure is properly configured
 */

const fs = require('fs');
const path = require('path');

const CHECKS = [
  // Configuration Files
  {
    name: 'jest.config.js exists',
    check: () => fs.existsSync('jest.config.js'),
    fix: 'Run: npm install --save-dev jest'
  },
  {
    name: '.env.test exists',
    check: () => fs.existsSync('.env.test'),
    fix: 'Create .env.test with test database configuration'
  },
  {
    name: 'tests/setup.js exists',
    check: () => fs.existsSync('tests/setup.js'),
    fix: 'Test setup file missing'
  },
  // Test Directories
  {
    name: 'tests/unit/services exists',
    check: () => fs.existsSync('tests/unit/services'),
    fix: 'Create unit test directory structure'
  },
  {
    name: 'tests/integration exists',
    check: () => fs.existsSync('tests/integration'),
    fix: 'Create integration test directory'
  },
  {
    name: 'tests/security exists',
    check: () => fs.existsSync('tests/security'),
    fix: 'Create security test directory'
  },
  {
    name: 'tests/api exists',
    check: () => fs.existsSync('tests/api'),
    fix: 'Create API test directory'
  },
  // Test Files
  {
    name: 'Unit test: authService.test.js',
    check: () => fs.existsSync('tests/unit/services/authService.test.js'),
    fix: 'Create authService unit tests'
  },
  {
    name: 'Unit test: taskService.test.js',
    check: () => fs.existsSync('tests/unit/services/taskService.test.js'),
    fix: 'Create taskService unit tests'
  },
  {
    name: 'Unit test: notificationService.test.js',
    check: () => fs.existsSync('tests/unit/services/notificationService.test.js'),
    fix: 'Create notificationService unit tests'
  },
  {
    name: 'Unit test: approvalService.test.js',
    check: () => fs.existsSync('tests/unit/services/approvalService.test.js'),
    fix: 'Create approvalService unit tests'
  },
  {
    name: 'Unit test: performanceService.test.js',
    check: () => fs.existsSync('tests/unit/services/performanceService.test.js'),
    fix: 'Create performanceService unit tests'
  },
  {
    name: 'Integration test: auth.integration.test.js',
    check: () => fs.existsSync('tests/integration/auth.integration.test.js'),
    fix: 'Create auth integration tests'
  },
  {
    name: 'Integration test: task.integration.test.js',
    check: () => fs.existsSync('tests/integration/task.integration.test.js'),
    fix: 'Create task integration tests'
  },
  {
    name: 'Integration test: approval.integration.test.js',
    check: () => fs.existsSync('tests/integration/approval.integration.test.js'),
    fix: 'Create approval integration tests'
  },
  {
    name: 'Integration test: notification.integration.test.js',
    check: () => fs.existsSync('tests/integration/notification.integration.test.js'),
    fix: 'Create notification integration tests'
  },
  {
    name: 'API test: endpoints.test.js',
    check: () => fs.existsSync('tests/api/endpoints.test.js'),
    fix: 'Create API endpoint tests'
  },
  {
    name: 'Security test: security.test.js',
    check: () => fs.existsSync('tests/security/security.test.js'),
    fix: 'Create security tests'
  },
  // Test Utilities
  {
    name: 'Test utilities: testHelper.js',
    check: () => fs.existsSync('tests/utils/testHelper.js'),
    fix: 'Create test helper utilities'
  },
  {
    name: 'Test utilities: database.js',
    check: () => fs.existsSync('tests/utils/database.js'),
    fix: 'Create database test utilities'
  },
  // Test Fixtures
  {
    name: 'Test fixture: users.fixture.js',
    check: () => fs.existsSync('tests/fixtures/users.fixture.js'),
    fix: 'Create user test fixtures'
  },
  {
    name: 'Test fixture: tasks.fixture.js',
    check: () => fs.existsSync('tests/fixtures/tasks.fixture.js'),
    fix: 'Create task test fixtures'
  },
  // Documentation
  {
    name: 'TEST_GUIDE.md exists',
    check: () => fs.existsSync('TEST_GUIDE.md'),
    fix: 'Create comprehensive testing guide'
  },
  {
    name: 'TEST_PROCEDURES.md exists',
    check: () => fs.existsSync('TEST_PROCEDURES.md'),
    fix: 'Create manual testing procedures'
  },
  // CI/CD
  {
    name: 'GitHub Actions workflow exists',
    check: () => fs.existsSync('.github/workflows/tests.yml'),
    fix: 'Create GitHub Actions CI/CD workflow'
  },
  // Dependencies
  {
    name: 'Jest in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.devDependencies && pkg.devDependencies.jest;
    },
    fix: 'npm install --save-dev jest'
  },
  {
    name: 'Supertest in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.devDependencies && pkg.devDependencies.supertest;
    },
    fix: 'npm install --save-dev supertest'
  },
  // Scripts
  {
    name: 'test:unit script in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.scripts && pkg.scripts['test:unit'];
    },
    fix: 'Add test:unit script to package.json'
  },
  {
    name: 'test:integration script in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.scripts && pkg.scripts['test:integration'];
    },
    fix: 'Add test:integration script to package.json'
  },
  {
    name: 'test:security script in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.scripts && pkg.scripts['test:security'];
    },
    fix: 'Add test:security script to package.json'
  },
  {
    name: 'test:ci script in package.json',
    check: () => {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      return pkg.scripts && pkg.scripts['test:ci'];
    },
    fix: 'Add test:ci script to package.json'
  }
];

// Run checks
console.log('\n========== TESTING SETUP VERIFICATION ==========\n');

let passed = 0;
let failed = 0;
const failures = [];

CHECKS.forEach((check) => {
  try {
    const result = check.check();
    const status = result ? 'PASS' : 'FAIL';
    const symbol = result ? '✓' : '✗';
    console.log(`${symbol} ${status}: ${check.name}`);
    
    if (result) {
      passed++;
    } else {
      failed++;
      failures.push(check);
    }
  } catch (error) {
    console.log(`✗ FAIL: ${check.name} (Error: ${error.message})`);
    failed++;
    failures.push(check);
  }
});

// Summary
console.log(`\n========== SUMMARY ==========`);
console.log(`Total Checks: ${CHECKS.length}`);
console.log(`Passed: ${passed}`);
console.log(`Failed: ${failed}`);

if (failures.length > 0) {
  console.log(`\n========== FAILURES & FIXES ==========\n`);
  failures.forEach(failure => {
    console.log(`✗ ${failure.name}`);
    console.log(`   Fix: ${failure.fix}\n`);
  });
}

console.log(`\n========== TESTING TARGETS ==========`);
console.log(`Coverage Target: 60%+`);
console.log(`Service Coverage Target: 70%+`);
console.log(`Test Count Target: 200+`);
console.log(`API Endpoint Tests: 40+`);

console.log(`\n========== NEXT STEPS ==========`);
console.log('1. Fix any failed checks');
console.log('2. Run: npm test');
console.log('3. Check coverage: npm test -- --coverage');
console.log('4. View coverage report: open coverage/lcov-report/index.html');
console.log('5. Read TEST_GUIDE.md for detailed instructions');
console.log('');

process.exit(failed > 0 ? 1 : 0);
