#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║     Real-Time Notifications System - Setup Verification      ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

let passCount = 0;
let totalChecks = 0;

function check(description, condition) {
  totalChecks++;
  const status = condition ? '✓ PASS' : '✗ FAIL';
  console.log(`${status}: ${description}`);
  if (condition) passCount++;
  return condition;
}

function checkFile(filePath, description) {
  const fullPath = path.join(__dirname, filePath);
  const exists = fs.existsSync(fullPath);
  check(`${description} (${filePath})`, exists);
  return exists;
}

function checkFileContent(filePath, searchString, description) {
  const fullPath = path.join(__dirname, filePath);
  if (!fs.existsSync(fullPath)) {
    check(`${description}`, false);
    return false;
  }
  const content = fs.readFileSync(fullPath, 'utf8');
  const found = content.includes(searchString);
  check(`${description}`, found);
  return found;
}

console.log('📦 Checking Models...');
checkFile('src/models/notification.js', 'Notification model exists');
checkFile('src/models/notificationPreference.js', 'NotificationPreference model exists');
checkFileContent('src/models/index.js', 'db.Notification = require', 'Notification model exported');
checkFileContent('src/models/index.js', 'db.NotificationPreference = require', 'NotificationPreference model exported');

console.log('\n📋 Checking Migrations...');
checkFile('src/migrations/20240101000016-create-notifications.js', 'Notifications table migration exists');
checkFile('src/migrations/20240101000017-create-notification-preferences.js', 'NotificationPreferences table migration exists');

console.log('\n🔧 Checking Services...');
checkFile('src/services/notificationService.js', 'NotificationService exists');
checkFileContent('src/services/notificationService.js', 'async createNotification', 'createNotification method exists');
checkFileContent('src/services/notificationService.js', 'async markAsRead', 'markAsRead method exists');
checkFileContent('src/services/notificationService.js', 'async getUnreadCount', 'getUnreadCount method exists');
checkFileContent('src/services/notificationService.js', 'async notifyTaskAssigned', 'notifyTaskAssigned method exists');
checkFileContent('src/services/notificationService.js', 'async notifyTaskCompleted', 'notifyTaskCompleted method exists');
checkFileContent('src/services/notificationService.js', 'async notifyTaskStatusChanged', 'notifyTaskStatusChanged method exists');

console.log('\n🎮 Checking Controllers...');
checkFile('src/controllers/notificationController.js', 'NotificationController exists');
checkFileContent('src/controllers/notificationController.js', 'exports.getUserNotifications', 'getUserNotifications handler exists');
checkFileContent('src/controllers/notificationController.js', 'exports.markAsRead', 'markAsRead handler exists');
checkFileContent('src/controllers/notificationController.js', 'exports.getUnreadCount', 'getUnreadCount handler exists');
checkFileContent('src/controllers/notificationController.js', 'exports.deleteNotification', 'deleteNotification handler exists');

console.log('\n🛣️  Checking Routes...');
checkFile('src/routes/notification.routes.js', 'Notification routes exist');
checkFileContent('src/routes/notification.routes.js', "router.get('/', notificationController", 'GET /notifications route exists');
checkFileContent('src/routes/notification.routes.js', "router.get('/count', notificationController", 'GET /notifications/count route exists');
checkFileContent('src/routes/notification.routes.js', "router.put('/:id/read'", 'PUT /notifications/:id/read route exists');
checkFileContent('src/routes/notification.routes.js', "router.delete('/:id'", 'DELETE /notifications/:id route exists');
checkFileContent('src/routes/index.js', "const notificationRoutes = require('./notification.routes')", 'Notification routes imported');
checkFileContent('src/routes/index.js', "router.use('/notifications', notificationRoutes)", 'Notification routes registered');

console.log('\n⚡ Checking Socket.io Integration...');
checkFile('src/config/socket.js', 'Socket.io config exists');
checkFileContent('src/config/socket.js', 'function initializeSocket', 'initializeSocket function exists');
checkFileContent('src/config/socket.js', 'io.use(async (socket, next)', 'Socket.io authentication middleware exists');
checkFileContent('src/config/socket.js', 'io.on(\'connection\'', 'Connection handler exists');
checkFileContent('src/config/socket.js', 'function emitToUser', 'emitToUser function exists');
checkFileContent('src/config/socket.js', 'function emitToDepartment', 'emitToDepartment function exists');
checkFileContent('src/config/socket.js', 'function emitToCompany', 'emitToCompany function exists');
checkFileContent('src/server.js', "const socketConfig = require('./config/socket')", 'Socket.io imported in server.js');
checkFileContent('src/server.js', 'const io = socketConfig.initializeSocket(server)', 'Socket.io initialized in server.js');
checkFileContent('src/server.js', 'global.io = io', 'Socket.io made globally available');

console.log('\n🔗 Checking Task Service Integration...');
checkFileContent('src/services/taskService.js', 'const NotificationService = require', 'NotificationService imported');
checkFileContent('src/services/taskService.js', 'NotificationService.notifyTaskAssigned', 'Task assignment notification trigger exists');
checkFileContent('src/services/taskService.js', 'NotificationService.notifyTaskCompleted', 'Task completion notification trigger exists');
checkFileContent('src/services/taskService.js', 'NotificationService.notifyTaskStatusChanged', 'Task status change notification trigger exists');

console.log('\n📚 Checking Documentation...');
checkFile('NOTIFICATIONS_GUIDE.md', 'Comprehensive notifications guide exists');

console.log('\n📦 Checking Dependencies...');
const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
check('socket.io package installed', !!packageJson.dependencies['socket.io']);
check('socket.io-client package installed', !!packageJson.dependencies['socket.io-client']);

// Summary
console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log(`║                    VERIFICATION SUMMARY                        ║`);
console.log('╠════════════════════════════════════════════════════════════════╣');
console.log(`║ Total Checks: ${totalChecks.toString().padEnd(56)}║`);
console.log(`║ Passed: ${passCount.toString().padEnd(60)}║`);
console.log(`║ Failed: ${(totalChecks - passCount).toString().padEnd(60)}║`);

if (passCount === totalChecks) {
  console.log('║                                                                ║');
  console.log('║ ✓ All checks passed! Notifications system is ready.            ║');
  console.log('║                                                                ║');
  console.log('║ Next Steps:                                                    ║');
  console.log('║ 1. Run: npm run db:migrate                                     ║');
  console.log('║ 2. Seed demo data: npm run seed:demo                           ║');
  console.log('║ 3. Start server: npm run dev                                   ║');
  console.log('║ 4. Test with: node test-notifications.js                       ║');
  console.log('║ 5. Read: NOTIFICATIONS_GUIDE.md for full documentation         ║');
} else {
  console.log('║                                                                ║');
  console.log(`║ ✗ ${totalChecks - passCount} check(s) failed. Please review above.            ║`);
}

console.log('╚════════════════════════════════════════════════════════════════╝\n');

process.exit(passCount === totalChecks ? 0 : 1);
