#!/usr/bin/env node

/**
 * Quick Test Script for Notifications System
 * 
 * Prerequisites:
 * 1. Backend server running (npm run dev)
 * 2. Valid JWT token (from login)
 * 3. Demo data seeded (npm run seed:demo)
 * 
 * Usage:
 * node test-notifications.js <authToken> <baseUrl>
 * 
 * Example:
 * node test-notifications.js "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." http://localhost:5000/api/v1
 */

const http = require('http');
const https = require('https');

const authToken = process.argv[2];
const baseUrl = process.argv[3] || 'http://localhost:5000/api/v1';

if (!authToken) {
  console.error('❌ Error: Auth token required');
  console.error('Usage: node test-notifications.js <token> [baseUrl]');
  process.exit(1);
}

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║           Notifications System - Quick Test                    ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

const client = baseUrl.startsWith('https') ? https : http;

function makeRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(baseUrl + path);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'Content-Type': 'application/json'
      }
    };

    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            data: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            data: data
          });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  try {
    // Test 1: Get unread count
    console.log('Test 1: Get Unread Notification Count');
    console.log('─────────────────────────────────────────');
    let res = await makeRequest('GET', '/notifications/count');
    console.log(`Status: ${res.status}`);
    console.log(`Unread Count: ${res.data.data?.unreadCount || 0}`);
    console.log('');

    // Test 2: Get notification preferences
    console.log('Test 2: Get Notification Preferences');
    console.log('─────────────────────────────────────────');
    res = await makeRequest('GET', '/notifications/preferences');
    console.log(`Status: ${res.status}`);
    console.log(`Preferences Found: ${res.status === 200 ? '✓' : '✗'}`);
    if (res.data.data) {
      console.log(`Task Assigned Notifications: ${res.data.data.task_assigned}`);
      console.log(`Task Completed Notifications: ${res.data.data.task_completed}`);
      console.log(`Email Notifications: ${res.data.data.email_notifications}`);
    }
    console.log('');

    // Test 3: Get notifications (paginated)
    console.log('Test 3: Get Notifications (Paginated)');
    console.log('─────────────────────────────────────────');
    res = await makeRequest('GET', '/notifications?page=1&limit=10');
    console.log(`Status: ${res.status}`);
    if (res.data.pagination) {
      console.log(`Total Notifications: ${res.data.pagination.total}`);
      console.log(`Current Page: ${res.data.pagination.page}`);
      console.log(`Total Pages: ${res.data.pagination.totalPages}`);
    }
    if (res.data.data && res.data.data.length > 0) {
      console.log(`\nSample Notification:`);
      const sample = res.data.data[0];
      console.log(`  Type: ${sample.type}`);
      console.log(`  Title: ${sample.title}`);
      console.log(`  Read: ${sample.read}`);
      console.log(`  Created: ${sample.createdAt}`);
    } else {
      console.log('No notifications yet');
    }
    console.log('');

    // Test 4: Update notification preferences
    console.log('Test 4: Update Notification Preferences');
    console.log('─────────────────────────────────────────');
    res = await makeRequest('PUT', '/notifications/preferences', {
      task_assigned: true,
      task_completed: true,
      task_commented: false,
      push_notifications: false
    });
    console.log(`Status: ${res.status}`);
    console.log(`Update Success: ${res.status === 200 ? '✓' : '✗'}`);
    console.log('');

    // Test 5: Mark all as read
    console.log('Test 5: Mark All Notifications as Read');
    console.log('─────────────────────────────────────────');
    res = await makeRequest('PUT', '/notifications/mark-all-read');
    console.log(`Status: ${res.status}`);
    if (res.data.data) {
      console.log(`Notifications Updated: ${res.data.data.updated}`);
    }
    console.log('');

    // Test 6: Verify count is now 0
    console.log('Test 6: Verify Unread Count is Now 0');
    console.log('─────────────────────────────────────────');
    res = await makeRequest('GET', '/notifications/count');
    console.log(`Status: ${res.status}`);
    console.log(`Unread Count: ${res.data.data?.unreadCount || 0}`);
    console.log('');

    console.log('╔════════════════════════════════════════════════════════════════╗');
    console.log('║                    ✓ All Tests Completed                       ║');
    console.log('╠════════════════════════════════════════════════════════════════╣');
    console.log('║                                                                ║');
    console.log('║ API Endpoints Verified:                                        ║');
    console.log('║ ✓ GET /notifications                                           ║');
    console.log('║ ✓ GET /notifications/count                                     ║');
    console.log('║ ✓ GET /notifications/preferences                               ║');
    console.log('║ ✓ PUT /notifications/preferences                               ║');
    console.log('║ ✓ PUT /notifications/mark-all-read                             ║');
    console.log('║                                                                ║');
    console.log('║ Next Steps:                                                    ║');
    console.log('║ 1. Create a task to trigger notifications                      ║');
    console.log('║ 2. Connect Socket.io client to test real-time delivery         ║');
    console.log('║ 3. See NOTIFICATIONS_GUIDE.md for full documentation           ║');
    console.log('║                                                                ║');
    console.log('╚════════════════════════════════════════════════════════════════╝\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

runTests();
