# Approval Workflow - Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### 1. Run Migrations
```bash
cd /home/ubuntu/Studioinfinito/backend
npm run migrate
```

### 2. Verify Setup
```bash
node verify-approval-setup.js
```

Expected output: `🎉 ALL CHECKS PASSED! Approval workflow is properly set up.`

### 3. Start Server
```bash
npm run dev
# Backend on http://localhost:5000/api/v1
```

### 4. Test with Demo Data
```bash
npm run seed:demo
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `APPROVAL_WORKFLOW_GUIDE.md` | Complete API reference & architecture |
| `APPROVAL_TESTING_GUIDE.md` | 10 test cases with detailed steps |
| `APPROVAL_IMPLEMENTATION_SUMMARY.md` | Implementation details & verification |
| `verify-approval-setup.js` | Automated verification script |
| `APPROVAL_QUICK_START.md` | This file |

---

## 🎯 Key Concepts

### Workflow Lifecycle
```
Task Complete → Submit for Approval → Manager Reviews → Approve/Reject
                                                           ↓
                                                      Finalized / In Progress
```

### Approver Assignment
Tasks are automatically assigned to the appropriate manager:
1. **Department Manager** ← Preferred
2. Department Head
3. Company Management
4. Superadmin (fallback)

### Approval Statuses
- **null** - Not submitted for approval yet
- **pending** - Waiting for manager's decision
- **approved** - Task finalized (✅)
- **rejected** - Returned for rework (⚠️)

---

## 🔑 Core API Endpoints

### Submit Task for Approval
```bash
POST /api/v1/approvals/:taskId/submit-for-approval

# Only task creator or assignee can submit
# Task must be in 'complete_pending_review' status
```

### Get Pending Approvals (Manager)
```bash
GET /api/v1/approvals/manager/pending-approvals
?page=1&limit=20&priority=high&department_id=1

# Returns paginated list of tasks waiting for approval
# Manager sees only their department's tasks
```

### Approve Task
```bash
PUT /api/v1/approvals/:taskId/approve
{ "comments": "Looks good!" }

# Task becomes 'finalized'
# Notifications sent to creator & assignee
```

### Reject Task
```bash
PUT /api/v1/approvals/:taskId/reject
{ "reason": "Need more details..." }

# Task returns to 'in_progress'
# Can be resubmitted after rework
```

### Get Approval History
```bash
GET /api/v1/approvals/:taskId/approval-history

# Returns complete audit trail of all approval actions
```

---

## 🔐 Role-Based Access

| Action | Manager | Dept Head | Management | Employee |
|--------|---------|-----------|------------|----------|
| Submit for approval | ✅ Own tasks | ✅ Own tasks | ✅ Any | ✅ Own tasks |
| View pending approvals | ✅ Own dept | ✅ Own dept | ✅ All | ❌ |
| Approve tasks | ✅ Own dept | ✅ Own dept | ✅ All | ❌ |
| Reject tasks | ✅ Own dept | ✅ Own dept | ✅ All | ❌ |
| View approval history | ✅ All | ✅ All | ✅ All | ✅ Own tasks |

---

## 📊 Database Tables

### Tasks Table (Modified)
**New columns:**
- `approval_status` - Current approval state
- `approver_id` - Manager who is/will approve
- `approval_comments` - Approval feedback
- `approval_date` - When approved/rejected
- `rejection_reason` - Why rejected (if rejected)

### Task Approvals Table (New)
**Records approval history:**
- `id`, `task_id`, `approver_id`, `status`
- `comments`, `reason`
- `submitted_at`, `reviewed_at`
- `created_at`, `updated_at`

---

## 🔔 Notifications

### Types
- `task_approval_pending` - Manager notified of new approval request
- `task_approval_approved` - Creator/assignee notified of approval
- `task_approval_rejected` - Creator/assignee notified of rejection with reason

### Delivery
- Database notifications (via `/notifications` API)
- Real-time WebSocket events (Socket.io)
- Respects user notification preferences

---

## 💾 Activity Logging

All approval actions logged in `task_activities`:
- `submitted_for_approval` - Task submitted
- `approved` - Task approved
- `reopened` - Task rejected (returns to in_progress)

---

## 🧪 Quick Test Workflow

### 1. Create & Complete Task (as Employee)
```bash
# Create task (as manager)
POST /tasks
{ "title": "Test task", "assigned_to": 3, ... }

# Mark complete (as assignee)
POST /tasks/1/complete

# Status becomes 'complete_pending_review'
```

### 2. Submit for Approval (as Employee)
```bash
POST /approvals/1/submit-for-approval

# Approver auto-assigned
# Status becomes 'pending'
```

### 3. Approve (as Manager)
```bash
PUT /approvals/1/approve
{ "comments": "Good work!" }

# Status becomes 'finalized'
# Notifications sent
```

---

## ✅ Verification Checklist

Run this to verify everything is set up:

```bash
# 1. Check installation
cd /home/ubuntu/Studioinfinito/backend
node verify-approval-setup.js

# 2. Should see: 🎉 ALL CHECKS PASSED!

# 3. Verify database
npm run migrate

# 4. Check migrations applied
mysql -u[user] -p[pass] studio_infinito -e "
  SELECT COUNT(*) as task_approvals FROM task_approvals;
  SHOW COLUMNS FROM tasks LIKE 'approval%';
"
```

---

## 🐛 Common Issues

### "Task cannot be submitted" (Status Error)
**Problem:** Task is not in `complete_pending_review` status
**Solution:** Mark task as complete first using `/tasks/:id/complete`

### "Not eligible to approve" (Permission Error)
**Problem:** User is not the correct manager
**Solution:** 
- Verify user has 'manager' or 'department_head' role
- Verify user is in the task's department
- Superadmin/management can approve any task

### Notification not received
**Problem:** User not receiving approval notifications
**Solution:**
- Check WebSocket connection (open DevTools Network tab)
- Verify notification preferences enabled
- Check notification logs in database

---

## 📁 File Structure

```
backend/
├── src/
│   ├── models/
│   │   ├── taskApproval.js ..................... NEW
│   │   ├── task.js ............................ MODIFIED
│   │   ├── taskActivity.js .................... MODIFIED
│   │   └── index.js ........................... MODIFIED
│   ├── services/
│   │   ├── approvalService.js ................. NEW
│   │   ├── notificationService.js ............. MODIFIED
│   │   └── taskService.js ..................... MODIFIED
│   ├── controllers/
│   │   └── approvalController.js .............. NEW
│   ├── routes/
│   │   ├── approval.routes.js ................. NEW
│   │   └── index.js ........................... MODIFIED
│   └── migrations/
│       ├── 20240101000018-*.js ................ NEW
│       ├── 20240101000019-*.js ................ NEW
│       ├── 20240101000020-*.js ................ NEW
│       └── 20240101000021-*.js ................ NEW
├── APPROVAL_WORKFLOW_GUIDE.md ................. NEW
├── APPROVAL_TESTING_GUIDE.md .................. NEW
├── APPROVAL_IMPLEMENTATION_SUMMARY.md ......... NEW
├── APPROVAL_QUICK_START.md .................... NEW
└── verify-approval-setup.js ................... NEW
```

---

## 📖 Learn More

**Full API Documentation:**
- See `APPROVAL_WORKFLOW_GUIDE.md` for complete details
- All endpoints documented with examples
- Request/response formats
- Error codes and messages

**Testing:**
- See `APPROVAL_TESTING_GUIDE.md` for 10 test cases
- Step-by-step testing procedures
- Database verification queries
- Troubleshooting section

**Implementation:**
- See `APPROVAL_IMPLEMENTATION_SUMMARY.md` for technical details
- Architecture overview
- Performance considerations
- Security notes

---

## 🚀 Next Steps

### For Development
1. ✅ Run migrations: `npm run migrate`
2. ✅ Verify setup: `node verify-approval-setup.js`
3. ✅ Test endpoints using `APPROVAL_TESTING_GUIDE.md`
4. ✅ Review code in `/src/services/approvalService.js`

### For Frontend Integration
1. Add "Submit for Approval" button on completed tasks
2. Add manager dashboard showing pending approvals
3. Add approve/reject forms with validation
4. Display approval history timeline
5. Show approval status badges on task cards
6. Real-time WebSocket notifications

### For Production
1. Load test approval endpoints
2. Monitor database query performance
3. Set up alerts for slow approvals
4. Configure notification preferences UI
5. Create approval reports/analytics

---

## 💡 Tips & Best Practices

### For Managers
- Check `pending-approvals-count` endpoint frequently
- Add comments when approving (helps with audit)
- Provide detailed rejection reasons
- Review approval history for patterns

### For Developers
- Always validate user permissions before approving
- Log all approval actions for debugging
- Test with different roles and departments
- Monitor notification delivery
- Keep audit trail for accountability

### For System Admins
- Monitor approval queue for stuck tasks
- Verify approver assignments after org changes
- Archive old approval records periodically
- Update database statistics for query optimization
- Set up alerts for high rejection rates

---

## 📞 Support

For issues or questions:
1. Check `APPROVAL_TESTING_GUIDE.md` troubleshooting section
2. Review error logs in console
3. Run `verify-approval-setup.js` to check setup
4. Query database to verify data integrity
5. Check WebSocket connection for real-time features

---

**Quick Links:**
- 📋 [Complete Guide](./APPROVAL_WORKFLOW_GUIDE.md)
- 🧪 [Testing Guide](./APPROVAL_TESTING_GUIDE.md)
- 📊 [Implementation Summary](./APPROVAL_IMPLEMENTATION_SUMMARY.md)
- ✅ [Verification Script](./verify-approval-setup.js)

*Last updated: 2026-04-06*
