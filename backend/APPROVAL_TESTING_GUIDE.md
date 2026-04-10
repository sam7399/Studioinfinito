# Approval Workflow - Testing Guide

## Prerequisites

Before testing, ensure:
1. Backend is running on `http://localhost:5000`
2. Database migrations have been run: `npm run migrate`
3. Demo data has been seeded: `npm run seed:demo`
4. You have valid authentication tokens for testing

## Quick Setup for Testing

### 1. Run Database Migrations

```bash
cd /home/ubuntu/Studioinfinito/backend
npm run migrate
```

### 2. Seed Demo Data (if not already done)

```bash
npm run seed:demo
```

### 3. Start Backend Server

```bash
npm run dev
# Backend runs on http://localhost:5000/api/v1
```

## Test Users

Use these demo credentials from `DEMO_CREDENTIALS.md`:

| Role | Email | Password | Department |
|------|-------|----------|------------|
| Manager | `priyasharma@demo.tsi` | `Demo@1234` | HR |
| Employee 1 | `rahulsingh@demo.tsi` | `Demo@1234` | HR |
| Employee 2 | `rohanverma@demo.tsi` | `Demo@1234` | Finance |
| Dept Head | `davidkumar@demo.tsi` | `Demo@1234` | HR |

---

## Test Case 1: Submit Task for Approval

### Goal
Test that an employee can submit a completed task for approval to their manager.

### Prerequisites
- Employee has completed a task
- Task status is `complete_pending_review`

### Steps

**1. Create a Task (as employee)**

```bash
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_EMPLOYEE_TOKEN" \
  -d '{
    "title": "Create test report",
    "description": "A test report for approval workflow testing",
    "priority": "high",
    "assigned_to": 3,
    "department_id": 1,
    "location_id": 1,
    "due_date": "2026-04-10",
    "estimated_hours": 5
  }'
```

**Response:** Note the task ID returned.

**2. Mark Task as Complete (as assignee)**

```bash
curl -X POST http://localhost:5000/api/v1/tasks/1/complete \
  -H "Authorization: Bearer YOUR_EMPLOYEE_TOKEN" \
  -d '{}'
```

**3. Submit for Approval (as assignee)**

```bash
curl -X POST http://localhost:5000/api/v1/approvals/1/submit-for-approval \
  -H "Authorization: Bearer YOUR_EMPLOYEE_TOKEN" \
  -d '{}'
```

### Expected Results
- ✅ Task status becomes `complete_pending_review`
- ✅ Approval status becomes `pending`
- ✅ Approver is automatically assigned (manager of the department)
- ✅ TaskApproval record created in database
- ✅ TaskActivity record logged with action `submitted_for_approval`
- ✅ Manager receives notification
- ✅ Response includes approver information

### Database Verification

```sql
-- Check task approval status
SELECT id, title, status, approval_status, approver_id FROM tasks WHERE id = 1;

-- Check approval record
SELECT id, task_id, approver_id, status, submitted_at FROM task_approvals WHERE task_id = 1;

-- Check activity log
SELECT id, task_id, action, note FROM task_activities WHERE task_id = 1 ORDER BY created_at DESC;

-- Check notifications
SELECT id, user_id, type, title FROM notifications WHERE task_id = 1 ORDER BY created_at DESC;
```

---

## Test Case 2: Get Pending Approvals

### Goal
Test that a manager can view their pending approvals.

### Steps

**1. Login as Manager**

```bash
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "priyasharma@demo.tsi",
    "password": "Demo@1234"
  }'
```

**Response:** Save the token from response.

**2. Get Pending Approvals**

```bash
curl -X GET http://localhost:5000/api/v1/approvals/manager/pending-approvals \
  -H "Authorization: Bearer YOUR_MANAGER_TOKEN"
```

**3. Get Pending Approvals Count**

```bash
curl -X GET http://localhost:5000/api/v1/approvals/manager/pending-approvals-count \
  -H "Authorization: Bearer YOUR_MANAGER_TOKEN"
```

### Expected Results
- ✅ Manager sees all pending approvals from their department
- ✅ Pagination works correctly
- ✅ Task details included (title, description, creator, assignee)
- ✅ Count matches number of pending items
- ✅ Employees cannot access this endpoint (403 error)

### Database Verification

```sql
-- Check pending approvals for manager
SELECT ta.id, ta.task_id, t.title, ta.status, ta.submitted_at 
FROM task_approvals ta
JOIN tasks t ON ta.task_id = t.id
WHERE ta.approver_id = 5 AND ta.status = 'pending';
```

---

## Test Case 3: Approve Task

### Goal
Test that a manager can approve a pending task.

### Steps

**1. Get a Pending Task ID (from Test Case 2)**

Note the task_id from pending approvals list.

**2. Approve the Task (as manager)**

```bash
curl -X PUT http://localhost:5000/api/v1/approvals/1/approve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_MANAGER_TOKEN" \
  -d '{
    "comments": "Excellent work! Report is comprehensive and well-structured."
  }'
```

### Expected Results
- ✅ Task status changes to `finalized`
- ✅ Approval status changes to `approved`
- ✅ Approval comments saved
- ✅ Approval date set
- ✅ TaskActivity logged with action `approved`
- ✅ TaskApproval record updated with status `approved` and `reviewed_at` timestamp
- ✅ Notifications sent to task creator and assignee
- ✅ Department team receives broadcast notification

### Database Verification

```sql
-- Check task approval
SELECT id, title, status, approval_status, approver_id, approval_comments, approval_date 
FROM tasks WHERE id = 1;

-- Check approval record
SELECT id, task_id, status, comments, reviewed_at 
FROM task_approvals WHERE task_id = 1 AND status = 'approved';

-- Check activity log
SELECT * FROM task_activities 
WHERE task_id = 1 AND action = 'approved' 
ORDER BY created_at DESC LIMIT 1;
```

---

## Test Case 4: Reject Task

### Goal
Test that a manager can reject a task and return it for rework.

### Prerequisites
- Task is submitted for approval (from Test Case 1)
- Not yet approved

### Steps

**1. Get a Pending Task ID**

From approvals list, select a pending task.

**2. Reject the Task (as manager)**

```bash
curl -X PUT http://localhost:5000/api/v1/approvals/2/reject \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_MANAGER_TOKEN" \
  -d '{
    "reason": "The report needs to include more detailed financial projections and risk analysis. Please revise and resubmit."
  }'
```

### Expected Results
- ✅ Task status changes to `in_progress` (returned for rework)
- ✅ Approval status changes to `rejected`
- ✅ Rejection reason saved
- ✅ Approval date set
- ✅ TaskActivity logged with action `reopened` and rejection note
- ✅ TaskApproval record updated with status `rejected` and `reviewed_at` timestamp
- ✅ Notifications sent to task creator and assignee with rejection reason
- ✅ Task can be resubmitted after rework

### Database Verification

```sql
-- Check task rejection
SELECT id, title, status, approval_status, rejection_reason, approval_date 
FROM tasks WHERE id = 2;

-- Check approval record
SELECT id, task_id, status, reason, reviewed_at 
FROM task_approvals WHERE task_id = 2 AND status = 'rejected';

-- Check activity log
SELECT * FROM task_activities 
WHERE task_id = 2 AND action = 'reopened' 
ORDER BY created_at DESC LIMIT 1;
```

---

## Test Case 5: Get Approval History

### Goal
Test that approval audit trail can be retrieved.

### Prerequisites
- Task has been submitted and approved/rejected (from Test Cases 3 or 4)

### Steps

**1. Get Approval History for a Task**

```bash
curl -X GET http://localhost:5000/api/v1/approvals/1/approval-history \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Expected Results
- ✅ Returns all approval records for the task
- ✅ Sorted by most recent first
- ✅ Includes approver information (name, email)
- ✅ Shows submission and review timestamps
- ✅ Contains comments/reasons

### Example Response
```json
{
  "success": true,
  "data": [
    {
      "id": 2,
      "task_id": 1,
      "approver_id": 5,
      "status": "approved",
      "comments": "Excellent work!",
      "reason": null,
      "submitted_at": "2026-04-06T10:30:00Z",
      "reviewed_at": "2026-04-06T11:00:00Z",
      "approver": {
        "id": 5,
        "name": "Priya Sharma",
        "email": "priyasharma@demo.tsi"
      }
    },
    {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "rejected",
      "comments": null,
      "reason": "Needs more details",
      "submitted_at": "2026-04-06T10:30:00Z",
      "reviewed_at": "2026-04-06T10:45:00Z",
      "approver": {
        "id": 5,
        "name": "Priya Sharma",
        "email": "priyasharma@demo.tsi"
      }
    }
  ]
}
```

---

## Test Case 6: Multi-step Approval Workflow

### Goal
Test complete workflow: Create → Complete → Submit → Reject → Rework → Resubmit → Approve

### Steps

**1. Create Task** (as manager)
```bash
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MANAGER_TOKEN" \
  -d '{
    "title": "Multi-step approval test",
    "assigned_to": 3,
    "department_id": 1,
    "location_id": 1,
    "due_date": "2026-04-10"
  }'
```

**2. Mark Complete** (as assignee)
```bash
curl -X POST http://localhost:5000/api/v1/tasks/3/complete \
  -H "Authorization: Bearer EMPLOYEE_TOKEN"
```

**3. Submit for Approval** (as assignee)
```bash
curl -X POST http://localhost:5000/api/v1/approvals/3/submit-for-approval \
  -H "Authorization: Bearer EMPLOYEE_TOKEN"
```

**4. Reject** (as manager)
```bash
curl -X PUT http://localhost:5000/api/v1/approvals/3/reject \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MANAGER_TOKEN" \
  -d '{
    "reason": "Need revisions"
  }'
```

**5. Verify Status is 'in_progress'**
```bash
curl -X GET http://localhost:5000/api/v1/tasks/3 \
  -H "Authorization: Bearer EMPLOYEE_TOKEN" | grep status
```

**6. Resubmit** (after rework)
```bash
curl -X POST http://localhost:5000/api/v1/approvals/3/submit-for-approval \
  -H "Authorization: Bearer EMPLOYEE_TOKEN"
```

**7. Approve** (as manager)
```bash
curl -X PUT http://localhost:5000/api/v1/approvals/3/approve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MANAGER_TOKEN" \
  -d '{
    "comments": "Looks good now!"
  }'
```

**8. Verify Final Status is 'finalized'**
```bash
curl -X GET http://localhost:5000/api/v1/tasks/3 \
  -H "Authorization: Bearer EMPLOYEE_TOKEN" | grep status
```

### Expected Results
- ✅ Task progresses through all states correctly
- ✅ Approval history shows both rejection and approval
- ✅ All notifications sent at appropriate times
- ✅ Activity log has complete record

---

## Test Case 7: Permission & Authorization

### Goal
Test that only authorized users can perform approval actions.

### Steps

**1. Try to Approve as Employee (should fail)**
```bash
curl -X PUT http://localhost:5000/api/v1/approvals/1/approve \
  -H "Authorization: Bearer EMPLOYEE_TOKEN"
```

**Expected:** 403 error

**2. Try to Submit for Approval as Someone Other Than Creator/Assignee (should fail)**

(Create task as user A, try to submit as user B)

**Expected:** 403 error

**3. Try to Get Approvals without Manager Role (should fail)**
```bash
curl -X GET http://localhost:5000/api/v1/approvals/manager/pending-approvals \
  -H "Authorization: Bearer EMPLOYEE_TOKEN"
```

**Expected:** 403 error

**4. Manager from Different Department Cannot Approve (should fail)**

(Task in Finance department, approve as HR manager)

**Expected:** 403 error

---

## Test Case 8: Notification Integration

### Goal
Test that notifications are sent correctly for all approval actions.

### Steps

**1. Submit Task and Check Notifications for Manager**

After submitting task, check manager's notifications:

```bash
curl -X GET http://localhost:5000/api/v1/notifications \
  -H "Authorization: Bearer MANAGER_TOKEN"
```

**Expected Results:**
- ✅ Notification type: `task_approval_pending`
- ✅ Title: "Task Pending Approval"
- ✅ Message contains task title and submitter name
- ✅ Metadata includes action: `approval_requested`

**2. Approve Task and Check Notifications for Assignee/Creator**

```bash
curl -X GET http://localhost:5000/api/v1/notifications \
  -H "Authorization: Bearer ASSIGNEE_TOKEN"
```

**Expected Results:**
- ✅ Notification type: `task_approval_approved`
- ✅ Title: "Task Approved"
- ✅ Message includes approver name
- ✅ Metadata includes action: `approval_approved`

**3. Reject Task and Check Notifications**

```bash
curl -X GET http://localhost:5000/api/v1/notifications \
  -H "Authorization: Bearer ASSIGNEE_TOKEN"
```

**Expected Results:**
- ✅ Notification type: `task_approval_rejected`
- ✅ Title: "Task Rejected"
- ✅ Message includes approver name and rejection reason
- ✅ Metadata includes action: `approval_rejected`

### Database Verification

```sql
-- Check all approval notifications
SELECT id, user_id, type, title, description, created_at 
FROM notifications 
WHERE type IN ('task_approval_pending', 'task_approval_approved', 'task_approval_rejected')
ORDER BY created_at DESC;
```

---

## Test Case 9: Approver Assignment Logic

### Goal
Test that the approver is assigned correctly based on hierarchy.

### Prerequisites
- Create tasks in departments with different management structures

### Scenario A: Manager Exists in Department

Create a task in HR (has manager Priya Sharma)

```bash
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Authorization: Bearer MANAGER_TOKEN" \
  -d '{"department_id": 1, ...}'
```

Submit for approval

**Expected:** Approver is Priya Sharma (manager)

### Scenario B: No Manager, But Department Head Exists

(Hypothetical: create a department without manager)

**Expected:** Approver is department head

### Database Verification

```sql
-- Check approver assignment
SELECT t.id, t.title, t.department_id, ta.approver_id, u.name, u.role 
FROM tasks t
JOIN task_approvals ta ON t.id = ta.task_id
JOIN users u ON ta.approver_id = u.id
WHERE t.id = 1;
```

---

## Test Case 10: Error Handling

### Goal
Test proper error messages and status codes.

### Test Scenarios

**1. Submit with Invalid Task ID**
```bash
curl -X POST http://localhost:5000/api/v1/approvals/99999/submit-for-approval \
  -H "Authorization: Bearer TOKEN"
```

**Expected:** 400 "Task not found"

**2. Approve Task Not in Pending Status**
```bash
# Create and approve a task, then try to approve again
curl -X PUT http://localhost:5000/api/v1/approvals/1/approve \
  -H "Authorization: Bearer MANAGER_TOKEN"
```

**Expected:** 400 "Task cannot be approved from 'finalized' status"

**3. Reject Without Reason**
```bash
curl -X PUT http://localhost:5000/api/v1/approvals/1/reject \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MANAGER_TOKEN" \
  -d '{"reason": ""}'
```

**Expected:** 400 "Rejection reason is required"

---

## Integration Tests

### Test Suite: Run All Tests in Sequence

```bash
#!/bin/bash

echo "=== Test 1: Submit for Approval ==="
# Create task, complete, submit
...

echo "=== Test 2: Approve ==="
# Get pending, approve
...

echo "=== Test 3: Reject and Resubmit ==="
# Reject, resubmit, approve
...

echo "=== Test 4: Permissions ==="
# Try unauthorized access
...

echo "=== Test 5: Notifications ==="
# Verify notifications
...

echo "=== All Tests Complete ==="
```

---

## Performance Testing

### Load Testing: Submit 100 Tasks for Approval

```bash
for i in {1..100}; do
  curl -X POST http://localhost:5000/api/v1/approvals/$i/submit-for-approval \
    -H "Authorization: Bearer TOKEN"
done
```

**Expected:**
- All requests complete successfully
- Response time < 500ms per request
- Database queries are efficient (using indexes)

---

## Manual Testing Checklist

- [ ] Create task successfully
- [ ] Mark task as complete
- [ ] Submit for approval (as creator)
- [ ] Submit for approval (as assignee)
- [ ] Cannot submit (wrong status)
- [ ] Manager can see pending approvals
- [ ] Employee cannot see pending approvals
- [ ] Manager can approve task
- [ ] Manager can reject task with reason
- [ ] Task returns to in_progress after rejection
- [ ] Can resubmit after rejection
- [ ] Approve second submission
- [ ] View approval history shows multiple records
- [ ] Notifications sent correctly
- [ ] Cross-department manager cannot approve
- [ ] Superadmin can approve any task
- [ ] Department head can approve own dept tasks
- [ ] Proper error messages for all failures

---

## Browser Developer Tools Testing

### Test WebSocket Notifications

**1. Open Browser Console**

Navigate to task management app (when integrated):

```javascript
// Open WebSocket connection details in Network tab
// Look for WebSocket connection to /socket.io/
// Monitor real-time events:
// - task_approval_pending
// - task_approval_approved
// - task_approval_rejected
```

**2. Test Real-time Updates**

- Submit task in one browser window
- Watch approver receive notification in real-time
- Approve/reject in manager window
- Watch assignee window update in real-time

---

## SQL Test Queries

### View All Approvals

```sql
SELECT 
  ta.id,
  t.title,
  t.status,
  ta.status as approval_status,
  u.name as approver,
  ta.submitted_at,
  ta.reviewed_at
FROM task_approvals ta
JOIN tasks t ON ta.task_id = t.id
JOIN users u ON ta.approver_id = u.id
ORDER BY ta.created_at DESC;
```

### Approval Statistics

```sql
-- Approval count by status
SELECT 
  ta.status,
  COUNT(*) as count
FROM task_approvals ta
GROUP BY ta.status;

-- Average approval time
SELECT 
  AVG(TIMESTAMPDIFF(HOUR, ta.submitted_at, ta.reviewed_at)) as avg_hours
FROM task_approvals ta
WHERE ta.reviewed_at IS NOT NULL;

-- Approvals by manager
SELECT 
  u.name,
  COUNT(*) as total_approvals,
  SUM(CASE WHEN ta.status = 'approved' THEN 1 ELSE 0 END) as approved,
  SUM(CASE WHEN ta.status = 'rejected' THEN 1 ELSE 0 END) as rejected
FROM task_approvals ta
JOIN users u ON ta.approver_id = u.id
GROUP BY ta.approver_id;
```

---

## Troubleshooting

### Issue: "No eligible approver found"
- **Check:** Department has manager or department head
- **Fix:** Create a manager or department head for the department

### Issue: Manager cannot approve
- **Check:** User has 'manager' or 'department_head' role
- **Check:** User is in the same department as the task
- **Fix:** Update user's department or role

### Issue: Notifications not appearing
- **Check:** Socket.io is running (check WebSocket in Network tab)
- **Check:** User's notification preferences are enabled
- **Fix:** Verify NotificationService is working (check logs)

### Issue: Permission denied on approval
- **Check:** User is the manager/dept head of the task's department
- **Check:** Task is in 'pending' approval status
- **Fix:** Try with correct user or check task status

---

## Success Criteria

After running all test cases, you should see:

- ✅ All CRUD operations work correctly
- ✅ Role-based access control enforced
- ✅ Approver auto-assignment works
- ✅ Approval status transitions are correct
- ✅ Notifications sent to right recipients
- ✅ Audit trail complete in activity log
- ✅ Error messages clear and helpful
- ✅ Performance acceptable (< 500ms per request)
- ✅ WebSocket real-time events working
- ✅ Database queries using indexes efficiently

*Last updated: 2026-04-06*
