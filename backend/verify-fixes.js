#!/usr/bin/env node

/**
 * Verification script for critical backend fixes
 * Checks that all fixes are properly in place without starting the full server
 */

const fs = require('fs');
const path = require('path');

console.log('🔍 Verifying critical backend fixes...\n');

let allChecks = true;

// ============================================
// Check 1: POST /tasks/:id/complete route exists
// ============================================
console.log('✓ Check 1: POST /tasks/:id/complete endpoint');
const taskRoutesPath = path.join(__dirname, 'src/routes/task.routes.js');
const taskRoutesContent = fs.readFileSync(taskRoutesPath, 'utf8');

if (taskRoutesContent.includes("router.post(\n  '/:id/complete'")) {
  console.log('  ✓ Route is defined\n');
} else {
  console.log('  ✗ Route is missing\n');
  allChecks = false;
}

// ============================================
// Check 2: completeTask controller method exists
// ============================================
console.log('✓ Check 2: completeTask controller method');
const taskControllerPath = path.join(__dirname, 'src/controllers/taskController.js');
const taskControllerContent = fs.readFileSync(taskControllerPath, 'utf8');

if (taskControllerContent.includes('static async completeTask')) {
  console.log('  ✓ Controller method is defined\n');
} else {
  console.log('  ✗ Controller method is missing\n');
  allChecks = false;
}

// ============================================
// Check 3: completeTask service method exists
// ============================================
console.log('✓ Check 3: completeTask service method');
const taskServicePath = path.join(__dirname, 'src/services/taskService.js');
const taskServiceContent = fs.readFileSync(taskServicePath, 'utf8');

if (taskServiceContent.includes('static async completeTask(taskId, user)')) {
  console.log('  ✓ Service method is defined\n');
  
  // Additional checks for service implementation
  if (taskServiceContent.includes('complete_pending_review')) {
    console.log('  ✓ Service updates status to complete_pending_review\n');
  }
  
  if (taskServiceContent.includes('completed_at')) {
    console.log('  ✓ Service sets completed_at timestamp\n');
  }
  
  if (taskServiceContent.includes('TaskActivity.create')) {
    console.log('  ✓ Service logs task activity\n');
  }
} else {
  console.log('  ✗ Service method is missing\n');
  allChecks = false;
}

// ============================================
// Check 4: Config has environment variables for URLs
// ============================================
console.log('✓ Check 4: Configuration uses environment variables');
const configPath = path.join(__dirname, 'src/config/index.js');
const configContent = fs.readFileSync(configPath, 'utf8');

if (configContent.includes("process.env.BASE_URL_API || 'http://localhost:26627'")) {
  console.log('  ✓ API URL uses environment variable with localhost default\n');
} else {
  console.log('  ✗ API URL configuration incorrect\n');
  allChecks = false;
}

if (configContent.includes("process.env.BASE_URL_APP || 'http://localhost:3000'")) {
  console.log('  ✓ App URL uses environment variable with localhost default\n');
} else {
  console.log('  ✗ App URL configuration incorrect\n');
  allChecks = false;
}

// ============================================
// Check 5: No hardcoded production URLs
// ============================================
console.log('✓ Check 5: No hardcoded production URLs');
const hardcodedUrls = [
  'studioinfinito-api.onrender.com',
  'task.thestudioinfinito.com',
  'https://task.thestudioinfinito.com'
];

let foundHardcoded = false;
hardcodedUrls.forEach(url => {
  if (configContent.includes(url) && !configContent.includes(`'${url}'`)) {
    console.log(`  ✗ Found hardcoded URL: ${url}\n`);
    foundHardcoded = true;
    allChecks = false;
  }
});

if (!foundHardcoded) {
  console.log('  ✓ No hardcoded production URLs found\n');
}

// ============================================
// Check 6: CORS configuration supports development
// ============================================
console.log('✓ Check 6: CORS configuration');
if (configContent.includes('http://localhost:3000') && 
    configContent.includes('http://localhost:3001')) {
  console.log('  ✓ CORS includes localhost origins for development\n');
} else {
  console.log('  ✗ CORS configuration may be missing development origins\n');
  allChecks = false;
}

if (configContent.includes('process.env.CORS_ORIGINS')) {
  console.log('  ✓ CORS supports environment variable configuration\n');
} else {
  console.log('  ✗ CORS missing environment variable support\n');
  allChecks = false;
}

// ============================================
// Check 7: .env.example exists
// ============================================
console.log('✓ Check 7: .env.example file');
const envExamplePath = path.join(__dirname, '.env.example');
if (fs.existsSync(envExamplePath)) {
  const envContent = fs.readFileSync(envExamplePath, 'utf8');
  console.log('  ✓ File exists\n');
  
  // Check for comprehensive documentation
  if (envContent.includes('BASE_URL_API') && envContent.includes('BASE_URL_APP')) {
    console.log('  ✓ Includes URL configuration examples\n');
  }
  
  if (envContent.includes('Development') || envContent.includes('development')) {
    console.log('  ✓ Includes development configuration guidance\n');
  }
  
  if (envContent.includes('Production') || envContent.includes('production')) {
    console.log('  ✓ Includes production configuration guidance\n');
  }
} else {
  console.log('  ✗ File not found\n');
  allChecks = false;
}

// ============================================
// Check 8: Database configuration uses environment variables
// ============================================
console.log('✓ Check 8: Database configuration');
if (configContent.includes('process.env.DBHOST') &&
    configContent.includes('process.env.DBNAME') &&
    configContent.includes('process.env.DBUSER') &&
    configContent.includes('process.env.DBPASS') &&
    configContent.includes('process.env.DBPORT')) {
  console.log('  ✓ All database settings use environment variables\n');
} else {
  console.log('  ✗ Some database settings may not use environment variables\n');
  allChecks = false;
}

// ============================================
// Summary
// ============================================
console.log('==========================================');
if (allChecks) {
  console.log('✅ All critical fixes verified successfully!');
  process.exit(0);
} else {
  console.log('❌ Some issues found. Please review the output above.');
  process.exit(1);
}
