# Manual Testing Procedures - Studioinfinito

This document provides comprehensive manual testing checklists and procedures for validating the Studioinfinito application.

## Table of Contents

1. [Pre-Testing Setup](#pre-testing-setup)
2. [User Authentication Testing](#user-authentication-testing)
3. [Task Management Testing](#task-management-testing)
4. [Approval Workflow Testing](#approval-workflow-testing)
5. [Notification Testing](#notification-testing)
6. [Performance Testing](#performance-testing)
7. [Browser Compatibility Testing](#browser-compatibility-testing)
8. [Load Testing](#load-testing)

## Pre-Testing Setup

### Requirements

- Node.js 18.x
- MySQL 5.7+
- Flutter SDK (for mobile/desktop)
- Chrome, Firefox, Safari browsers
- Postman or curl for API testing
- Terminal/Command Prompt access

### Database Setup

```bash
# 1. Create database
mysql -u root
CREATE DATABASE task_manager CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;

# 2. Seed demo data
cd backend
npm run seed:demo

# 3. Verify seeding
mysql -u root -e "USE task_manager; SELECT COUNT(*) as user_count FROM users;"
```

### Application Startup

```bash
# Terminal 1: Start Backend
cd backend
npm run dev
# Should see: "Server running on port 5000"

# Terminal 2: Start Frontend
cd frontend
flutter run
# Should see: "Launching lib/main.dart on ..."
```

## User Authentication Testing

### Test Case 1: Superadmin Login

**Steps**:
1. Open application
2. Click "Login"
3. Enter Email: `admin@demo.tsi`
4. Enter Password: `TSI@Demo#2025`
5. Click "Login"

**Expected Results**:
- ✅ Login succeeds
- ✅ Dashboard displays
- ✅ All menu items visible
- ✅ Can access all departments

**Database Verification**:
```sql
SELECT id, username, role, last_login_at FROM users WHERE emp_code = 'DEMO_SUPERADMIN';
```

### Test Case 2: Department Head Login

**Steps**:
1. Logout from previous user
2. Login with: `hr.head@demo.tsi` / `Demo@1234`
3. Verify dashboard

**Expected Results**:
- ✅ Login succeeds
- ✅ See only HR department tasks
- ✅ Cannot see other departments' tasks
- ✅ Approval menu visible

### Test Case 3: Employee Login

**Steps**:
1. Logout
2. Login with: `hr.emp1@demo.tsi` / `Demo@1234`
3. Check task visibility

**Expected Results**:
- ✅ Login succeeds
- ✅ See own tasks and assigned tasks
- ✅ Cross-department tasks show limited info
- ✅ Cannot create/edit other's tasks

### Test Case 4: Invalid Credentials

**Steps**:
1. Login with invalid email: `invalid@test.com`
2. Try any password
3. Click Login

**Expected Results**:
- ✅ Error message: "Invalid credentials"
- ✅ Not logged in
- ✅ Form still visible for retry

### Test Case 5: Inactive User

**Steps**:
1. (Admin) Create a test user and mark as inactive
2. Try to login with that user

**Expected Results**:
- ✅ Login rejected
- ✅ Error: "Account is inactive. Please contact your administrator."

## Task Management Testing

### Test Case 1: Create Task

**Steps**:
1. Login as management user
2. Click "New Task"
3. Fill in:
   - Title: "Integration Test Task"
   - Description: "Testing task creation"
   - Assign to: Any employee
   - Priority: High
   - Target Date: 7 days from today
4. Click "Create"

**Expected Results**:
- ✅ Task created successfully
- ✅ Notification sent to assignee
- ✅ Task appears in list
- ✅ Activity log created

**Database Verification**:
```sql
SELECT id, title, status, assigned_to FROM tasks 
WHERE title = 'Integration Test Task' ORDER BY created_at DESC LIMIT 1;

SELECT action, actor_user_id FROM task_activities 
WHERE action = 'created' ORDER BY created_at DESC LIMIT 1;
```

### Test Case 2: Update Task

**Steps**:
1. Open a created task
2. Edit:
   - Status: "In Progress"
   - Priority: "Medium"
3. Click "Save"

**Expected Results**:
- ✅ Changes saved
- ✅ Activity log created
- ✅ Timestamp updated

### Test Case 3: Mark Task Complete

**Steps**:
1. Open an "In Progress" task
2. Click "Mark as Complete"
3. Confirm

**Expected Results**:
- ✅ Status changes to "Completed"
- ✅ Completion timestamp recorded
- ✅ Notification sent to creator
- ✅ Available for review

**API Verification**:
```bash
curl -X POST http://localhost:5000/api/v1/tasks/1/complete \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"

# Expected response: 200 OK with updated task
```

### Test Case 4: Delete Task

**Steps**:
1. Open a task (as creator or admin)
2. Click "Delete"
3. Confirm deletion

**Expected Results**:
- ✅ Task deleted
- ✅ Removed from list
- ✅ Cannot retrieve deleted task
- ✅ Activity logged

### Test Case 5: Task Visibility (Cross-Department)

**Steps**:
1. (HR Employee) Create task assigned to Finance employee
2. Login as Operations employee
3. View task list
4. Click on the HR task

**Expected Results**:
- ✅ Task appears in list
- ✅ Shows: Title + Target Date only (🔒 lock icon)
- ✅ Description hidden
- ✅ Assignee hidden
- ✅ Progress hidden

## Approval Workflow Testing

### Test Case 1: Submit Task for Approval

**Steps**:
1. Login as employee
2. Complete a task
3. Click "Submit for Approval"
4. Confirm

**Expected Results**:
- ✅ Task status: "Submitted for Review"
- ✅ Approval status: "Pending"
- ✅ Manager receives notification
- ✅ Task appears in manager's pending approvals

**Database Verification**:
```sql
SELECT id, approval_status, approver_id FROM tasks WHERE status = 'submitted_for_review';
SELECT * FROM task_activities WHERE action = 'submitted_for_approval';
```

### Test Case 2: Approve Task

**Steps**:
1. Login as manager
2. Go to "Pending Approvals"
3. Open a pending task
4. Click "Approve"
5. Add comment (optional)
6. Confirm

**Expected Results**:
- ✅ Task status: "Submitted for Review"
- ✅ Approval status: "Approved"
- ✅ Approval date set
- ✅ Employee notified
- ✅ Activity logged

### Test Case 3: Reject Task

**Steps**:
1. Login as manager
2. Go to "Pending Approvals"
3. Open a task
4. Click "Reject"
5. Enter reason: "Needs more details"
6. Confirm

**Expected Results**:
- ✅ Task status: "In Progress"
- ✅ Approval status: "Rejected"
- ✅ Rejection reason saved
- ✅ Employee notified with reason
- ✅ Can be resubmitted

### Test Case 4: Resubmit After Rejection

**Steps**:
1. Login as employee (task was rejected)
2. Open rejected task
3. Make changes
4. Click "Submit for Approval" again
5. Confirm

**Expected Results**:
- ✅ New approval request created
- ✅ Previous rejection visible in history
- ✅ Manager receives new notification
- ✅ Can be approved or rejected again

### Test Case 5: View Approval History

**Steps**:
1. Open any task with approval activity
2. Click "Approval History"
3. Review timeline

**Expected Results**:
- ✅ Shows all approval events
- ✅ Chronological order
- ✅ Includes: Submit, Approve/Reject, Comments
- ✅ Shows who approved/rejected and when

## Notification Testing

### Test Case 1: Receive Task Assignment Notification

**Steps**:
1. Login as manager
2. Create and assign task to employee
3. Check employee's notifications

**Expected Results**:
- ✅ Notification appears
- ✅ Notification bell shows count
- ✅ Clicking shows details
- ✅ Can mark as read
- ✅ Database has notification record

### Test Case 2: Notification Preferences

**Steps**:
1. Login as any user
2. Go to Settings → Notifications
3. Disable "Email Notifications"
4. Save

**Expected Results**:
- ✅ Preferences saved
- ✅ No emails sent for tasks going forward
- ✅ In-app notifications still work
- ✅ Setting persists after logout/login

### Test Case 3: Real-time WebSocket Notification

**Steps**:
1. Open two browser tabs (login same user)
2. In tab 1: Create/assign a task
3. Check tab 2: Notification appears immediately

**Expected Results**:
- ✅ No page refresh needed
- ✅ Notification appears within 1 second
- ✅ WebSocket connection active

**Browser DevTools Verification**:
1. Open DevTools → Network → WS
2. Should see connection to WebSocket
3. Check messages for notification events

### Test Case 4: Mark Notification as Read

**Steps**:
1. Open notifications
2. Click on unread notification
3. Click "Mark as Read"

**Expected Results**:
- ✅ Notification marked as read
- ✅ Read timestamp set
- ✅ Unread count decreases
- ✅ Visual indicator updated

## Performance Testing

### Test Case 1: Page Load Time

**Steps**:
1. Open DevTools → Performance
2. Reload page
3. Check metrics

**Expected Results**:
- ✅ First Contentful Paint < 2s
- ✅ Largest Contentful Paint < 4s
- ✅ Cumulative Layout Shift < 0.1

### Test Case 2: Task List Pagination

**Steps**:
1. Open Tasks page
2. Scroll to bottom
3. Load more tasks

**Expected Results**:
- ✅ Pagination works smoothly
- ✅ No noticeable lag
- ✅ Handles 100+ tasks

### Test Case 3: Search Performance

**Steps**:
1. Open search
2. Type search query
3. Monitor response time

**Expected Results**:
- ✅ Results < 1 second
- ✅ Debouncing prevents excessive requests

## Browser Compatibility Testing

### Test Browsers

- Google Chrome (Latest)
- Mozilla Firefox (Latest)
- Apple Safari (Latest)
- Microsoft Edge (Latest)

### Test Case: Cross-Browser Functionality

For each browser, test:

1. **Login**: Email + password input, submission
2. **Dashboard**: Layout, menus, buttons
3. **Task Creation**: Form, validation, submission
4. **Notifications**: Real-time updates, WebSocket
5. **Approval**: Full workflow

**Expected Results**:
- ✅ All features work in all browsers
- ✅ No console errors
- ✅ UI renders correctly
- ✅ No visual glitches

## Load Testing

### Basic Load Test with Apache Bench

```bash
# Install Apache Bench
sudo apt-get install apache2-utils  # Linux
brew install httpd  # macOS

# Test login endpoint (100 requests, 10 concurrent)
ab -n 100 -c 10 \
  -p credentials.json \
  -T application/json \
  http://localhost:5000/api/v1/auth/login

# Test task list endpoint (with authentication)
ab -n 100 -c 10 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/v1/tasks
```

### Load Test Checklist

- [ ] Response time < 500ms at 10 concurrent users
- [ ] Response time < 1s at 50 concurrent users
- [ ] No database connection errors
- [ ] No memory leaks
- [ ] Server recovers after load

## Testing Summary Checklist

### Authentication (6 tests)
- [ ] Superadmin login
- [ ] Department head login
- [ ] Employee login
- [ ] Invalid credentials rejection
- [ ] Inactive user rejection
- [ ] Password reset flow

### Task Management (5 tests)
- [ ] Create task
- [ ] Update task
- [ ] Mark complete
- [ ] Delete task
- [ ] Cross-department visibility

### Approval Workflow (5 tests)
- [ ] Submit for approval
- [ ] Approve task
- [ ] Reject task
- [ ] Resubmit after rejection
- [ ] View approval history

### Notifications (4 tests)
- [ ] Receive notification
- [ ] Notification preferences
- [ ] Real-time updates
- [ ] Mark as read

### Performance (3 tests)
- [ ] Page load time
- [ ] Pagination
- [ ] Search performance

### Browser Compatibility (4 tests)
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

**Total Tests**: 27 Manual Test Cases

## Reporting Issues

If you find a bug during testing:

1. Document the exact steps to reproduce
2. Take screenshots/videos
3. Note the expected vs actual behavior
4. Record any error messages
5. Check the browser console for errors
6. Create a GitHub issue with full details
