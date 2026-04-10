# Manager Approval Workflow - Complete Guide

## Overview

The manager approval workflow allows tasks to go through an approval process before being finalized. When a task is marked as complete, the creator or assignee can submit it for approval to their department manager or department head. The approver can then approve or reject the task.

### Key Features

- **Approval Request Submission**: Task creator or assignee can submit completed tasks for approval
- **Approver Assignment**: Automatic routing to appropriate manager/department head
- **Approval/Rejection**: Managers can approve or reject tasks with comments/reasons
- **Audit Trail**: Complete history of all approval actions
- **Real-time Notifications**: WebSocket-based notifications for approvers and team
- **Department Privacy**: Respects existing RBAC and department privacy rules
- **Activity Logging**: All approval actions logged in task activity history

---

## Database Schema

### Task Model Updates

Added five new fields to the `tasks` table:

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `approval_status` | ENUM('pending', 'approved', 'rejected') | YES | Current approval status. NULL = not submitted for approval |
| `approver_id` | INTEGER (FK: users.id) | YES | User ID of the approver |
| `approval_comments` | TEXT | YES | Comments from approver when approving |
| `approval_date` | DATETIME | YES | Timestamp of approval/rejection |
| `rejection_reason` | TEXT | YES | Reason for rejection if rejected |

**Indexes:**
- `idx_tasks_approval_status`
- `idx_tasks_approver_id`
- `idx_tasks_approval_status_approver`

### TaskApproval Model

New table `task_approvals` tracks approval history for audit trail:

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | INTEGER | NO | Primary key |
| `task_id` | INTEGER (FK) | NO | Reference to task |
| `approver_id` | INTEGER (FK) | NO | ID of approver |
| `status` | ENUM | NO | 'pending', 'approved', or 'rejected' |
| `comments` | TEXT | YES | Approval comments |
| `reason` | TEXT | YES | Rejection reason |
| `submitted_at` | DATETIME | NO | When task was submitted for approval |
| `reviewed_at` | DATETIME | YES | When approver reviewed the task |
| `created_at` | DATETIME | NO | Record creation timestamp |
| `updated_at` | DATETIME | NO | Record update timestamp |

**Indexes:**
- `idx_task_approvals_task_id`
- `idx_task_approvals_approver_id`
- `idx_task_approvals_status`
- `idx_task_approvals_approver_status` (compound)
- `idx_task_approvals_created_at`
- `idx_task_approvals_task_status` (compound)

---

## API Endpoints

### 1. Submit Task for Approval

**Endpoint:** `POST /api/v1/approvals/:id/submit-for-approval`

**Authorization:** Required (any authenticated user)

**Description:** Submit a completed task for approval. Only the task creator or assignee can submit.

**Parameters:**
- `id` (URL) - Task ID (required)

**Response:**
```json
{
  "success": true,
  "message": "Task submitted for approval",
  "data": {
    "id": 1,
    "title": "Complete project proposal",
    "status": "complete_pending_review",
    "approval_status": "pending",
    "approver_id": 5,
    "approver": {
      "id": 5,
      "name": "Priya Sharma",
      "email": "priyasharma@company.com"
    },
    "approval": {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "pending",
      "submitted_at": "2026-04-06T10:30:00Z"
    }
  }
}
```

**Errors:**
- `400`: Task not found or cannot be submitted for approval (wrong status)
- `403`: User doesn't have permission (not creator/assignee)
- `500`: Internal error

**Business Logic:**
- Task must be in `complete_pending_review` status
- Only creator or assignee can submit
- Finds appropriate approver (manager > dept head > management > superadmin)
- Creates TaskApproval record with status 'pending'
- Logs activity and sends notifications

---

### 2. Get Pending Approvals

**Endpoint:** `GET /api/v1/approvals/manager/pending-approvals`

**Authorization:** Required (managers, department heads, management, superadmin)

**Description:** Get all tasks pending approval for the current user (if they're an approver).

**Query Parameters:**
- `page` (optional, default: 1) - Page number for pagination
- `limit` (optional, default: 20, max: 100) - Items per page
- `priority` (optional) - Filter by priority ('low', 'normal', 'high', 'urgent')
- `department_id` (optional) - Filter by department

**Response:**
```json
{
  "success": true,
  "message": "Pending approvals retrieved",
  "data": [
    {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "pending",
      "submitted_at": "2026-04-06T10:30:00Z",
      "created_at": "2026-04-06T10:30:00Z",
      "updated_at": "2026-04-06T10:30:00Z",
      "task": {
        "id": 1,
        "title": "Complete project proposal",
        "description": "Prepare comprehensive proposal...",
        "status": "complete_pending_review",
        "approval_status": "pending",
        "priority": "high",
        "due_date": "2026-04-10",
        "creator": {
          "id": 2,
          "name": "John Doe",
          "email": "john@company.com"
        },
        "assignee": {
          "id": 3,
          "name": "Jane Smith",
          "email": "jane@company.com"
        },
        "department": {
          "id": 1,
          "name": "Operations"
        }
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 5,
    "pages": 1
  }
}
```

**Errors:**
- `403`: User is not a manager/department head
- `500`: Internal error

**Business Logic:**
- For managers: Show tasks from their department only
- For department heads: Show tasks from their department
- For management/superadmin: Show all tasks
- Returns paginated list sorted by most recent first

---

### 3. Get Pending Approvals Count

**Endpoint:** `GET /api/v1/approvals/manager/pending-approvals-count`

**Authorization:** Required (managers, department heads, management, superadmin)

**Description:** Get the count of pending approvals for the current user.

**Response:**
```json
{
  "success": true,
  "message": "Pending approvals count retrieved",
  "data": {
    "count": 3
  }
}
```

**Errors:**
- `500`: Internal error

---

### 4. Approve Task

**Endpoint:** `PUT /api/v1/approvals/:id/approve`

**Authorization:** Required (managers, department heads, management, superadmin)

**Description:** Approve a task that is pending approval.

**Parameters:**
- `id` (URL) - Task ID (required)

**Request Body:**
```json
{
  "comments": "Great work! Task completed as expected." // optional
}
```

**Response:**
```json
{
  "success": true,
  "message": "Task approved successfully",
  "data": {
    "task": {
      "id": 1,
      "title": "Complete project proposal",
      "status": "finalized",
      "approval_status": "approved",
      "approver_id": 5,
      "approval_comments": "Great work! Task completed as expected.",
      "approval_date": "2026-04-06T11:00:00Z"
    },
    "approval": {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "approved",
      "comments": "Great work! Task completed as expected.",
      "reviewed_at": "2026-04-06T11:00:00Z"
    }
  }
}
```

**Errors:**
- `400`: Task not found or cannot be approved (wrong status)
- `403`: User is not eligible to approve this task
- `500`: Internal error

**Business Logic:**
- Task must have `approval_status = 'pending'`
- Approver must be eligible (manager/dept head of same department, or management/superadmin)
- Updates task `status = 'finalized'`
- Updates task `approval_status = 'approved'`
- Logs 'approved' activity
- Sends notifications to task creator and assignee
- Broadcasts approval event to department team

---

### 5. Reject Task

**Endpoint:** `PUT /api/v1/approvals/:id/reject`

**Authorization:** Required (managers, department heads, management, superadmin)

**Description:** Reject a task that is pending approval. Task returns to 'in_progress' status.

**Parameters:**
- `id` (URL) - Task ID (required)

**Request Body:**
```json
{
  "reason": "The proposal needs more details about budget and timeline" // required
}
```

**Response:**
```json
{
  "success": true,
  "message": "Task rejected successfully",
  "data": {
    "task": {
      "id": 1,
      "title": "Complete project proposal",
      "status": "in_progress",
      "approval_status": "rejected",
      "approver_id": 5,
      "rejection_reason": "The proposal needs more details about budget and timeline",
      "approval_date": "2026-04-06T11:00:00Z"
    },
    "approval": {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "rejected",
      "reason": "The proposal needs more details about budget and timeline",
      "reviewed_at": "2026-04-06T11:00:00Z"
    }
  }
}
```

**Errors:**
- `400`: Task not found, cannot be rejected (wrong status), or missing reason
- `403`: User is not eligible to reject this task
- `500`: Internal error

**Business Logic:**
- Task must have `approval_status = 'pending'`
- Reason is required (minimum 1 character, maximum 1000 characters)
- Approver must be eligible
- Updates task `status = 'in_progress'` (returns for rework)
- Updates task `approval_status = 'rejected'`
- Logs 'reopened' activity
- Sends notifications to task creator and assignee with reason
- Broadcasts rejection event to department team

---

### 6. Get Approval History

**Endpoint:** `GET /api/v1/approvals/:id/approval-history`

**Authorization:** Required (any authenticated user)

**Description:** Get the approval audit trail for a task (all approval records).

**Parameters:**
- `id` (URL) - Task ID (required)

**Response:**
```json
{
  "success": true,
  "message": "Approval history retrieved",
  "data": [
    {
      "id": 2,
      "task_id": 1,
      "approver_id": 5,
      "status": "approved",
      "comments": "Great work! Task completed as expected.",
      "reason": null,
      "submitted_at": "2026-04-06T10:30:00Z",
      "reviewed_at": "2026-04-06T11:00:00Z",
      "created_at": "2026-04-06T11:00:00Z",
      "approver": {
        "id": 5,
        "name": "Priya Sharma",
        "email": "priyasharma@company.com"
      }
    },
    {
      "id": 1,
      "task_id": 1,
      "approver_id": 5,
      "status": "rejected",
      "comments": null,
      "reason": "The proposal needs more details",
      "submitted_at": "2026-04-06T10:30:00Z",
      "reviewed_at": "2026-04-06T10:45:00Z",
      "created_at": "2026-04-06T10:45:00Z",
      "approver": {
        "id": 5,
        "name": "Priya Sharma",
        "email": "priyasharma@company.com"
      }
    }
  ]
}
```

**Errors:**
- `404`: Task not found
- `500`: Internal error

**Business Logic:**
- Returns all approval records for a task, sorted by most recent first
- Includes approver information
- Respects task privacy rules (cross-department users see limited info)

---

## Approver Assignment Logic

When a task is submitted for approval, the system automatically assigns it to the appropriate approver using this hierarchy:

1. **Department Manager** - If the task's department has a manager
2. **Department Head** - If no manager exists
3. **Management** - If no department manager or head exists
4. **Superadmin** - As fallback

```
Department Manager
        ↓ (if not found)
Department Head
        ↓ (if not found)
Company Management
        ↓ (if not found)
Superadmin
```

---

## Workflow States

### Task Lifecycle with Approvals

```
┌─────────────────────────────────────────────────────────────┐
│ TASK CREATION (status: 'open')                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
         ┌───────────────────────┐
         │   Work in Progress    │
         │   (status: 'in_progress')│
         └───────────┬───────────┘
                     │
                     ↓
     ┌───────────────────────────────────┐
     │ Marked as Complete (without review)
     │ (status: 'complete_pending_review')
     └───────────┬───────────────────────┘
                 │
                 ↓
   ┌─────────────────────────────┐
   │ Submit for Approval         │
   │ (approval_status: 'pending') │
   └──┬──────────────────────┬───┘
      │                      │
      ↓ APPROVE              ↓ REJECT
   ┌──────────┐        ┌──────────────┐
   │Finalized │        │Back to Work  │
   │(approved)│        │(in_progress) │
   └──────────┘        └──────────────┘
```

### Approval Status Values

- **NULL** - No approval requested (not submitted yet)
- **'pending'** - Waiting for approver's decision
- **'approved'** - Task approved and finalized
- **'rejected'** - Task rejected and returned for rework

---

## Notifications

### Notification Types

The approval workflow uses these notification types:

| Type | When Triggered | Recipients | Real-time (Socket.io) |
|------|---|---|---|
| `task_approval_pending` | Task submitted for approval | Assigned approver | YES |
| `task_approval_approved` | Task approved | Task creator, assignee | YES (to department) |
| `task_approval_rejected` | Task rejected | Task creator, assignee | YES (to department) |

### Notification Flow

```
Task Submitted → Approver notified (real-time)
                 ↓
        Manager Reviews
                 ↓
        Approves/Rejects
                 ↓
        Task Creator/Assignee notified (real-time)
        Department team notified (broadcast)
```

### Socket.io Events

**When task is submitted for approval:**
```javascript
socket.on('task_approval_pending', {
  taskId: 1,
  taskTitle: 'Complete project proposal',
  submittedBy: 3,
  submitterName: 'John Doe'
});
```

**When task is approved:**
```javascript
socket.on('task_approval_approved', {
  taskId: 1,
  taskTitle: 'Complete project proposal',
  approvedBy: 'Priya Sharma'
});
```

**When task is rejected:**
```javascript
socket.on('task_approval_rejected', {
  taskId: 1,
  taskTitle: 'Complete project proposal',
  rejectedBy: 'Priya Sharma',
  reason: 'The proposal needs more details about budget and timeline'
});
```

---

## RBAC & Department Privacy

### Who Can Submit for Approval?
- Task creator
- Task assignee

### Who Can Approve/Reject?
- **Superadmin** - Can approve any task in any department/company
- **Management** - Can approve any task in their company
- **Department Head** - Can approve tasks in their department only
- **Manager** - Can approve tasks in their department only
- **Employee** - Cannot approve (read-only)

### Privacy Rules
- **Cross-department task access**: Respects existing department privacy rules
- **Task details visibility**: Non-approvers see limited task details for cross-department tasks
- **Approval history**: Only visible to approvers and relevant task stakeholders

---

## Activity Logging

All approval actions are logged in `task_activities` table:

| Action | When | Actor | Note Example |
|--------|------|-------|---|
| `submitted_for_approval` | Task submitted for approval | Submitter | "Task submitted for approval to John Doe" |
| `approved` | Task approved | Approver | "Task approved" |
| `reopened` | Task rejected | Approver | "Task rejected: Needs more details" |

---

## Integration with Existing Systems

### Task Model
- Uses existing `complete_pending_review` status
- Adds approval-specific fields (non-intrusive)
- Extends `Task.associate` for approver relationship

### Notifications
- Uses existing `NotificationService`
- Adds new notification types to ENUM
- Supports real-time Socket.io events

### Activity Logging
- Uses existing `TaskActivity` model
- Extends action ENUM with new actions

### RBAC
- Uses existing `RBACService`
- Respects role-based access rules
- Enforces department privacy masking

---

## Error Handling

### Common Error Scenarios

**Task Not Found (404)**
```json
{
  "success": false,
  "message": "Task not found"
}
```

**Cannot Submit for Approval (400)**
```json
{
  "success": false,
  "message": "Task cannot be submitted for approval from 'open' status"
}
```

**Permission Denied (403)**
```json
{
  "success": false,
  "message": "Only task creator or assignee can submit for approval"
}
```

**Invalid Rejection Reason (400)**
```json
{
  "success": false,
  "message": "Rejection reason is required"
}
```

**Not Eligible Approver (403)**
```json
{
  "success": false,
  "message": "User is not eligible to approve this task"
}
```

---

## Migration Files

Three new migration files have been created:

1. **`20240101000018-add-approval-fields-to-tasks.js`**
   - Adds approval fields to tasks table
   - Creates indexes for approval queries

2. **`20240101000019-create-task-approvals.js`**
   - Creates task_approvals table for audit trail
   - Sets up relationships and indexes

3. **`20240101000020-add-approval-notification-types.js`**
   - Adds new notification types to ENUM
   - `task_approval_pending`, `task_approval_approved`, `task_approval_rejected`

4. **`20240101000021-add-approval-actions-to-task-activities.js`**
   - Adds new action types to task_activities ENUM
   - `submitted_for_approval`, `rejected`

---

## Files Created/Modified

### New Files
- `/src/models/taskApproval.js` - TaskApproval model
- `/src/services/approvalService.js` - Business logic service
- `/src/controllers/approvalController.js` - Route controllers
- `/src/routes/approval.routes.js` - API routes
- `/src/migrations/20240101000018-*.js` - Database migrations (4 files)

### Modified Files
- `/src/models/task.js` - Added approval fields and relationships
- `/src/models/taskActivity.js` - Added new action types
- `/src/models/index.js` - Registered TaskApproval model
- `/src/services/taskService.js` - Added TaskApproval import
- `/src/services/notificationService.js` - Added approval notification methods
- `/src/routes/index.js` - Registered approval routes

---

## Example Workflows

### Scenario 1: Successful Approval

```
1. Task marked complete (status: 'complete_pending_review')
2. Assignee submits for approval
   - Approver: Priya Sharma (Manager)
   - Status: 'pending'
3. Manager approves with comments
   - Task status: 'finalized'
   - Approval status: 'approved'
4. Notifications sent to creator and assignee
5. Department team sees approval in broadcast
```

### Scenario 2: Rejection and Rework

```
1. Task submitted for approval
2. Manager reviews and rejects
   - Reason: "Budget section needs revision"
3. Task returns to 'in_progress'
   - Approval status: 'rejected'
4. Notifications sent with rejection reason
5. Assignee reworks the task
6. Submits again for approval
   - New approval record created
7. (Scenario repeats)
```

### Scenario 3: Multi-level Escalation

```
1. Task submitted for approval to department manager
2. Manager out of office or unavailable
3. System automatically routes to department head
4. Department head approves/rejects
5. Notifications reflect final decision
```

---

## Testing Procedures

See the [Testing Guide](#testing-guide) section at the end of this document.

---

## Development Notes

### Key Design Decisions

1. **Separate TaskApproval Table** - Maintains audit trail while keeping Task model changes minimal
2. **Automatic Approver Assignment** - Reduces friction, follows org hierarchy
3. **Non-blocking Notifications** - Service errors don't block approval workflow
4. **Activity Logging** - All actions logged for accountability and debugging
5. **Real-time WebSocket Events** - Instant updates for approvers and teams

### Performance Considerations

- **Indexed Queries** - Approval lookups use indexes on `approval_status`, `approver_id`
- **Pagination** - Approval lists are paginated (default 20 per page, max 100)
- **Efficient Includes** - Only includes related models when needed
- **Async Notifications** - Notifications don't block main request

### Security Considerations

- **Role-based Access** - Only managers/heads can approve
- **Department Isolation** - Managers only see their department's tasks
- **Audit Trail** - All actions logged with timestamps and user IDs
- **Input Validation** - Celebration middleware validates all inputs
- **Activity Logging** - Complete history for accountability

---

## Future Enhancements

1. **Multi-level Approvals** - Require multiple approvals for high-priority tasks
2. **Approval Deadlines** - Auto-escalate tasks if not approved within X days
3. **Approval Delegation** - Managers can delegate approval authority
4. **Bulk Approvals** - Approve/reject multiple tasks at once
5. **Approval Templates** - Predefined comments for common rejection reasons
6. **Approval Analytics** - Reports on approval times, rejection rates
7. **Conditional Approvals** - Route based on task properties (budget > $X, etc.)
8. **Approval Comments** - Full conversation thread between approver and assignee

---

## Troubleshooting

### Task Cannot Be Submitted for Approval

**Issue**: "Task cannot be submitted for approval from 'open' status"

**Solution**: Task must be in `complete_pending_review` status. Mark task as complete first.

### "Not Eligible to Approve"

**Issue**: Manager cannot approve tasks

**Solution**: Verify user has 'manager' or 'department_head' role and is in the same department as the task.

### No Approver Found

**Issue**: "No eligible approver found for this task"

**Solution**: Ensure department has a manager or department head. Contact system admin.

### Notifications Not Received

**Issue**: Approver doesn't see notifications

**Solution**: Check WebSocket connection and notification preferences. Verify approver's notification settings are enabled.

---

## Support

For issues or questions, contact the development team.

*Last updated: 2026-04-06*
