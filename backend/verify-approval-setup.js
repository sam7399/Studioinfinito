#!/usr/bin/env node

/**
 * Approval Workflow Setup Verification Script
 * 
 * This script verifies that all components of the manager approval workflow
 * have been properly implemented.
 * 
 * Usage: node verify-approval-setup.js
 */

const fs = require('fs');
const path = require('path');

const CHECKS = [];
let passed = 0;
let failed = 0;

// Helper function to check if file exists
function checkFileExists(filePath, description) {
  const fullPath = path.join(__dirname, filePath);
  if (fs.existsSync(fullPath)) {
    console.log(`✅ PASS: ${description}`);
    passed++;
    CHECKS.push({ status: 'PASS', description });
  } else {
    console.log(`❌ FAIL: ${description} - File not found: ${filePath}`);
    failed++;
    CHECKS.push({ status: 'FAIL', description });
  }
}

// Helper function to check if file contains text
function checkFileContent(filePath, searchText, description) {
  const fullPath = path.join(__dirname, filePath);
  try {
    const content = fs.readFileSync(fullPath, 'utf8');
    if (content.includes(searchText)) {
      console.log(`✅ PASS: ${description}`);
      passed++;
      CHECKS.push({ status: 'PASS', description });
    } else {
      console.log(`❌ FAIL: ${description} - Text not found in ${filePath}`);
      failed++;
      CHECKS.push({ status: 'FAIL', description });
    }
  } catch (error) {
    console.log(`❌ FAIL: ${description} - Error reading file: ${error.message}`);
    failed++;
    CHECKS.push({ status: 'FAIL', description });
  }
}

console.log('\n' + '='.repeat(70));
console.log('  APPROVAL WORKFLOW SETUP VERIFICATION');
console.log('='.repeat(70) + '\n');

// ============================================================================
// 1. MODEL FILES
// ============================================================================
console.log('\n📋 MODELS & DATABASE SCHEMA\n');

checkFileExists('src/models/taskApproval.js', 'TaskApproval model created');
checkFileContent('src/models/task.js', 'approval_status', 'Task model has approval_status field');
checkFileContent('src/models/task.js', 'approver_id', 'Task model has approver_id field');
checkFileContent('src/models/task.js', 'approval_comments', 'Task model has approval_comments field');
checkFileContent('src/models/task.js', 'approval_date', 'Task model has approval_date field');
checkFileContent('src/models/task.js', 'rejection_reason', 'Task model has rejection_reason field');
checkFileContent('src/models/task.js', 'TaskApproval', 'Task model has TaskApproval association');
checkFileContent('src/models/index.js', 'TaskApproval', 'TaskApproval model imported in index.js');
checkFileContent('src/models/taskActivity.js', 'submitted_for_approval', 'TaskActivity has submitted_for_approval action');

// ============================================================================
// 2. MIGRATION FILES
// ============================================================================
console.log('\n📦 DATABASE MIGRATIONS\n');

checkFileExists('src/migrations/20240101000018-add-approval-fields-to-tasks.js', 'Migration for Task table updates');
checkFileExists('src/migrations/20240101000019-create-task-approvals.js', 'Migration for TaskApproval table creation');
checkFileExists('src/migrations/20240101000020-add-approval-notification-types.js', 'Migration for notification types');
checkFileExists('src/migrations/20240101000021-add-approval-actions-to-task-activities.js', 'Migration for activity actions');

// ============================================================================
// 3. SERVICE FILES
// ============================================================================
console.log('\n⚙️  SERVICES\n');

checkFileExists('src/services/approvalService.js', 'ApprovalService created');
checkFileContent('src/services/approvalService.js', 'submitForApproval', 'ApprovalService has submitForApproval method');
checkFileContent('src/services/approvalService.js', 'getTasksForApproval', 'ApprovalService has getTasksForApproval method');
checkFileContent('src/services/approvalService.js', 'approveTask', 'ApprovalService has approveTask method');
checkFileContent('src/services/approvalService.js', 'rejectTask', 'ApprovalService has rejectTask method');
checkFileContent('src/services/approvalService.js', 'getApprovalHistory', 'ApprovalService has getApprovalHistory method');
checkFileContent('src/services/approvalService.js', 'getPendingApprovalsCount', 'ApprovalService has getPendingApprovalsCount method');
checkFileContent('src/services/approvalService.js', '_findApproverForTask', 'ApprovalService has approver assignment logic');
checkFileContent('src/services/approvalService.js', '_isEligibleApprover', 'ApprovalService has approval eligibility check');

checkFileContent('src/services/notificationService.js', 'notifyTaskSubmittedForApproval', 'NotificationService has approval pending notification');
checkFileContent('src/services/notificationService.js', 'notifyTaskApproved', 'NotificationService has approval notification');
checkFileContent('src/services/notificationService.js', 'notifyTaskRejected', 'NotificationService has rejection notification');
checkFileContent('src/services/taskService.js', 'TaskApproval', 'TaskService imports TaskApproval');

// ============================================================================
// 4. CONTROLLER FILES
// ============================================================================
console.log('\n🎮 CONTROLLERS\n');

checkFileExists('src/controllers/approvalController.js', 'ApprovalController created');
checkFileContent('src/controllers/approvalController.js', 'submitForApproval', 'ApprovalController has submitForApproval handler');
checkFileContent('src/controllers/approvalController.js', 'getPendingApprovals', 'ApprovalController has getPendingApprovals handler');
checkFileContent('src/controllers/approvalController.js', 'approveTask', 'ApprovalController has approveTask handler');
checkFileContent('src/controllers/approvalController.js', 'rejectTask', 'ApprovalController has rejectTask handler');
checkFileContent('src/controllers/approvalController.js', 'getApprovalHistory', 'ApprovalController has getApprovalHistory handler');
checkFileContent('src/controllers/approvalController.js', 'getPendingApprovalsCount', 'ApprovalController has getPendingApprovalsCount handler');

// ============================================================================
// 5. ROUTE FILES
// ============================================================================
console.log('\n🛣️  ROUTES\n');

checkFileExists('src/routes/approval.routes.js', 'Approval routes file created');
checkFileContent('src/routes/approval.routes.js', '/submit-for-approval', 'Routes have submit-for-approval endpoint');
checkFileContent('src/routes/approval.routes.js', '/manager/pending-approvals', 'Routes have pending-approvals endpoint');
checkFileContent('src/routes/approval.routes.js', '/approve', 'Routes have approve endpoint');
checkFileContent('src/routes/approval.routes.js', '/reject', 'Routes have reject endpoint');
checkFileContent('src/routes/approval.routes.js', '/approval-history', 'Routes have approval-history endpoint');
checkFileContent('src/routes/approval.routes.js', 'approvalController', 'Routes use ApprovalController');

checkFileContent('src/routes/index.js', 'approval.routes', 'Main routes import approval.routes');
checkFileContent('src/routes/index.js', 'approvalRoutes', 'Main routes register approval routes');

// ============================================================================
// 6. DOCUMENTATION FILES
// ============================================================================
console.log('\n📚 DOCUMENTATION\n');

checkFileExists('APPROVAL_WORKFLOW_GUIDE.md', 'Complete API documentation created');
checkFileExists('APPROVAL_TESTING_GUIDE.md', 'Testing guide created');

// ============================================================================
// 7. VALIDATION CHECKS
// ============================================================================
console.log('\n✔️  VALIDATION CHECKS\n');

// Check that ApprovalService methods are properly structured
try {
  const approvalContent = fs.readFileSync(path.join(__dirname, 'src/services/approvalService.js'), 'utf8');
  
  // Check for async methods
  if (approvalContent.includes('static async submitForApproval')) {
    console.log('✅ PASS: ApprovalService methods are async');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'ApprovalService methods are async' });
  } else {
    console.log('❌ FAIL: ApprovalService methods are not async');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'ApprovalService methods are not async' });
  }

  // Check for error handling
  if (approvalContent.includes('throw new Error')) {
    console.log('✅ PASS: ApprovalService has error handling');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'ApprovalService has error handling' });
  } else {
    console.log('❌ FAIL: ApprovalService lacks error handling');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'ApprovalService lacks error handling' });
  }

  // Check for notifications integration
  if (approvalContent.includes('NotificationService')) {
    console.log('✅ PASS: ApprovalService integrates with NotificationService');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'ApprovalService integrates with NotificationService' });
  } else {
    console.log('❌ FAIL: ApprovalService does not integrate with NotificationService');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'ApprovalService does not integrate with NotificationService' });
  }

  // Check for activity logging
  if (approvalContent.includes('TaskActivity.create')) {
    console.log('✅ PASS: ApprovalService logs activities');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'ApprovalService logs activities' });
  } else {
    console.log('❌ FAIL: ApprovalService does not log activities');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'ApprovalService does not log activities' });
  }
} catch (error) {
  console.log(`❌ FAIL: Error validating ApprovalService: ${error.message}`);
  failed++;
  CHECKS.push({ status: 'FAIL', description: 'Error validating ApprovalService' });
}

// Check routes have proper validation
try {
  const routesContent = fs.readFileSync(path.join(__dirname, 'src/routes/approval.routes.js'), 'utf8');
  
  if (routesContent.includes('celebrate') && routesContent.includes('Joi')) {
    console.log('✅ PASS: Approval routes have input validation');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'Approval routes have input validation' });
  } else {
    console.log('❌ FAIL: Approval routes lack input validation');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'Approval routes lack input validation' });
  }

  if (routesContent.includes('authenticate') && routesContent.includes('requireRole')) {
    console.log('✅ PASS: Approval routes have authentication and authorization');
    passed++;
    CHECKS.push({ status: 'PASS', description: 'Approval routes have authentication and authorization' });
  } else {
    console.log('❌ FAIL: Approval routes lack authentication/authorization');
    failed++;
    CHECKS.push({ status: 'FAIL', description: 'Approval routes lack authentication/authorization' });
  }
} catch (error) {
  console.log(`❌ FAIL: Error validating routes: ${error.message}`);
  failed++;
  CHECKS.push({ status: 'FAIL', description: 'Error validating routes' });
}

// ============================================================================
// SUMMARY
// ============================================================================

console.log('\n' + '='.repeat(70));
console.log('  VERIFICATION SUMMARY');
console.log('='.repeat(70) + '\n');

const total = passed + failed;
const passPercentage = total > 0 ? Math.round((passed / total) * 100) : 0;

console.log(`✅ Passed: ${passed}`);
console.log(`❌ Failed: ${failed}`);
console.log(`📊 Total:  ${total}`);
console.log(`📈 Pass Rate: ${passPercentage}%\n`);

if (failed === 0) {
  console.log('🎉 ALL CHECKS PASSED! Approval workflow is properly set up.\n');
  process.exit(0);
} else {
  console.log(`⚠️  ${failed} check(s) failed. Please review the items marked with ❌\n`);
  process.exit(1);
}
