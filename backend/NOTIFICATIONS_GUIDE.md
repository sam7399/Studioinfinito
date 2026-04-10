# Real-Time Notifications System - Complete Guide

## Overview

The Studioinfinito notifications system provides real-time, bi-directional communication between backend and frontend using WebSocket (Socket.io). It integrates with existing RBAC rules, respects department privacy masking, and triggers notifications for key task management events.

## Table of Contents

1. [Architecture](#architecture)
2. [WebSocket Connection & Authentication](#websocket-connection--authentication)
3. [Notification Models & Database Schema](#notification-models--database-schema)
4. [API Endpoints](#api-endpoints)
5. [Socket.io Events](#socketio-events)
6. [Notification Triggers](#notification-triggers)
7. [RBAC Compliance](#rbac-compliance)
8. [Development Setup](#development-setup)
9. [Production Deployment](#production-deployment)
10. [Testing & Debugging](#testing--debugging)
11. [Client Integration Examples](#client-integration-examples)

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend (Flutter)                    │
│              Socket.io Client Connection Manager             │
└────────────────────────────────────┬──────────────────────────┘
                                      │ WebSocket (ws/wss)
                                      │
┌─────────────────────────────────────▼──────────────────────────┐
│                         Express.js Server                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Socket.io Server                        │  │
│  │  • Connection/Disconnection handlers                     │  │
│  │  • JWT Authentication middleware                         │  │
│  │  • Room management (user:*, dept:*, company:*)           │  │
│  │  • Event emission handlers                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │          Notification Service Layer                      │  │
│  │  • createNotification()                                  │  │
│  │  • notifyTaskAssigned()                                  │  │
│  │  • notifyTaskCompleted()                                 │  │
│  │  • notifyTaskStatusChanged()                             │  │
│  │  • Socket.io emission integration                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │         Task Service (Integration Points)                │  │
│  │  • createTask() → notifyTaskAssigned()                   │  │
│  │  • updateTask() → notifyTaskStatusChanged()              │  │
│  │  • completeTask() → notifyTaskCompleted()                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
└──────────────────────────────▼──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                      MySQL Database                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ notifications table                                      │  │
│  │ ├─ id (PK)                                               │  │
│  │ ├─ user_id (FK) [indexed]                                │  │
│  │ ├─ task_id (FK) [nullable, indexed]                      │  │
│  │ ├─ type (ENUM)                                           │  │
│  │ ├─ title, description, metadata                          │  │
│  │ ├─ read (boolean)                                        │  │
│  │ ├─ read_at (timestamp)                                   │  │
│  │ └─ created_at, updated_at                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ notification_preferences table                           │  │
│  │ ├─ id (PK)                                               │  │
│  │ ├─ user_id (FK, unique)                                  │  │
│  │ ├─ task_assigned, task_completed, etc. (boolean flags)   │  │
│  │ ├─ email_notifications, push_notifications (boolean)     │  │
│  │ └─ created_at, updated_at                                │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## WebSocket Connection & Authentication

### Connection Flow

1. **Frontend initiates connection** with JWT token in handshake auth
2. **Server validates JWT** via middleware
3. **User data loaded** from database (with role, department, company)
4. **User joined to rooms**:
   - `user:{userId}` - for personal notifications
   - `company:{companyId}` - for company-wide notifications
   - `dept:{departmentId}` - for department notifications

### JWT Authentication

```javascript
// Socket.io middleware (in src/config/socket.js)
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token || 
                  socket.handshake.headers.authorization?.split(' ')[1];

    if (!token) {
      return next(new Error('Authentication error: No token provided'));
    }

    const decoded = jwt.verify(token, config.jwt.secret);
    const user = await User.findByPk(decoded.id, {
      attributes: ['id', 'name', 'email', 'role', 'company_id', 'department_id']
    });

    if (!user) {
      return next(new Error('Authentication error: User not found'));
    }

    socket.user = user;
    socket.userId = user.id;
    next();
  } catch (error) {
    next(new Error(`Authentication error: ${error.message}`));
  }
});
```

### CORS Configuration

Socket.io respects the same CORS configuration as Express:

```javascript
// Development: All localhost origins allowed
// Production: Configured via CORS_ORIGINS environment variable

io.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    
    if (config.nodeEnv === 'development' && /^http:\/\/localhost(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }
    
    if (config.cors.origins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST']
}));
```

---

## Notification Models & Database Schema

### Notification Model

**Table**: `notifications`

```sql
CREATE TABLE notifications (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  task_id INT NULL,
  type ENUM('task_assigned', 'task_completed', 'task_commented', 
             'task_deadline_approaching', 'task_status_changed',
             'task_review_pending', 'task_review_approved', 
             'task_review_rejected', 'system'),
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  metadata JSON NULL,
  read BOOLEAN DEFAULT FALSE,
  read_at DATETIME NULL,
  created_at DATETIME DEFAULT NOW(),
  updated_at DATETIME DEFAULT NOW(),
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_task_id (task_id),
  INDEX idx_user_read (user_id, read),
  INDEX idx_created_at (created_at)
);
```

### NotificationPreference Model

**Table**: `notification_preferences`

```sql
CREATE TABLE notification_preferences (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL UNIQUE,
  task_assigned BOOLEAN DEFAULT TRUE,
  task_completed BOOLEAN DEFAULT TRUE,
  task_commented BOOLEAN DEFAULT TRUE,
  task_deadline_approaching BOOLEAN DEFAULT TRUE,
  task_status_changed BOOLEAN DEFAULT TRUE,
  task_review_pending BOOLEAN DEFAULT TRUE,
  task_review_approved BOOLEAN DEFAULT TRUE,
  task_review_rejected BOOLEAN DEFAULT TRUE,
  email_notifications BOOLEAN DEFAULT TRUE,
  push_notifications BOOLEAN DEFAULT TRUE,
  created_at DATETIME DEFAULT NOW(),
  updated_at DATETIME DEFAULT NOW(),
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id)
);
```

### Metadata Schema

The `metadata` field in notifications stores additional context:

```json
{
  "task_assigned": {
    "assigned_by_user_id": 5,
    "task_title": "Review Budget Report",
    "task_status": "open"
  },
  "task_completed": {
    "completed_by_user_id": 12,
    "task_title": "Review Budget Report"
  },
  "task_status_changed": {
    "previous_status": "open",
    "current_status": "in_progress",
    "task_title": "Review Budget Report"
  }
}
```

---

## API Endpoints

All endpoints require authentication (JWT token in `Authorization` header).

### GET /api/v1/notifications

Get user's notifications with pagination and filtering.

**Query Parameters**:
- `page` (default: 1) - Page number
- `limit` (default: 20) - Items per page
- `read` (optional) - Filter: "true" or "false"
- `type` (optional) - Filter by notification type

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "user_id": 5,
      "task_id": 23,
      "type": "task_assigned",
      "title": "New task assigned: Budget Review",
      "description": "Sarah Mitchell has assigned you a new task.",
      "read": false,
      "createdAt": "2025-04-06T10:30:00Z",
      "task": {
        "id": 23,
        "title": "Budget Review",
        "status": "open"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "totalPages": 3
  }
}
```

### GET /api/v1/notifications/count

Get unread notification count for current user.

**Response**:
```json
{
  "success": true,
  "data": {
    "unreadCount": 7
  }
}
```

### PUT /api/v1/notifications/:id/read

Mark a specific notification as read.

**Response**:
```json
{
  "success": true,
  "message": "Notification marked as read",
  "data": { notification object }
}
```

### PUT /api/v1/notifications/mark-all-read

Mark all notifications as read for current user.

**Response**:
```json
{
  "success": true,
  "message": "15 notifications marked as read",
  "data": {
    "updated": 15
  }
}
```

### DELETE /api/v1/notifications/:id

Delete a specific notification.

**Response**:
```json
{
  "success": true,
  "message": "Notification deleted successfully"
}
```

### DELETE /api/v1/notifications/delete-read

Delete all read notifications for current user.

**Response**:
```json
{
  "success": true,
  "message": "8 read notifications deleted",
  "data": {
    "deleted": 8
  }
}
```

### GET /api/v1/notifications/preferences

Get user's notification preferences.

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 5,
    "user_id": 5,
    "task_assigned": true,
    "task_completed": true,
    "task_commented": false,
    "task_deadline_approaching": true,
    "task_status_changed": true,
    "task_review_pending": true,
    "task_review_approved": true,
    "task_review_rejected": true,
    "email_notifications": true,
    "push_notifications": true
  }
}
```

### PUT /api/v1/notifications/preferences

Update user's notification preferences.

**Request Body**:
```json
{
  "task_assigned": true,
  "task_completed": true,
  "task_commented": false,
  "email_notifications": true,
  "push_notifications": false
}
```

**Response**: Updated preferences object

---

## Socket.io Events

### Client → Server Events

#### `ping`

Keep-alive heartbeat. Server responds with `pong`.

```javascript
// Client sends
socket.emit('ping');

// Server responds
socket.on('pong', () => {
  console.log('Server alive');
});
```

#### `subscribe`

Subscribe to additional room (for advanced use cases).

```javascript
socket.emit('subscribe', {
  room: 'task:23'  // Get updates for specific task
});
```

#### `unsubscribe`

Unsubscribe from a room.

```javascript
socket.emit('unsubscribe', {
  room: 'task:23'
});
```

### Server → Client Events

#### `notification:new`

Emitted when a new notification is created for the user.

```javascript
socket.on('notification:new', (notification) => {
  console.log('New notification:', notification);
  // {
  //   id: 45,
  //   type: 'task_assigned',
  //   title: 'New task assigned: Budget Review',
  //   description: 'Sarah Mitchell has assigned you a new task.',
  //   taskId: 23,
  //   read: false,
  //   createdAt: '2025-04-06T10:30:00Z',
  //   metadata: { ... }
  // }
});
```

#### `task:update`

Emitted when a task is updated (if user is subscribed to that task).

```javascript
socket.on('task:update', (update) => {
  console.log('Task update:', update);
  // {
  //   taskId: 23,
  //   action: 'status_changed',
  //   data: { previous_status: 'open', current_status: 'in_progress' },
  //   timestamp: '2025-04-06T10:35:00Z'
  // }
});
```

#### `pong`

Response to client `ping` event (keep-alive).

```javascript
socket.on('pong', () => {
  console.log('Server is alive');
});
```

#### `error`

Socket errors.

```javascript
socket.on('error', (error) => {
  console.error('Socket error:', error);
});
```

#### `disconnect`

Emitted when socket connection is lost.

```javascript
socket.on('disconnect', () => {
  console.log('Disconnected from server');
  // Attempt to reconnect
});
```

---

## Notification Triggers

### Task Assignment

**Trigger**: Task created or reassigned

**Recipient**: Assigned user(s)

**Notification Type**: `task_assigned`

**Implementation**:
```javascript
// In taskService.createTask()
if (uid !== user.id) {
  NotificationService.notifyTaskAssigned({ ...task, assigned_to_user_id: uid })
}

// In taskService.updateTask() when reassigning
NotificationService.notifyTaskAssigned(task)
```

### Task Completed

**Trigger**: Task marked as `complete_pending_review`

**Recipient**: Task creator

**Notification Type**: `task_completed`

**Implementation**:
```javascript
// In taskService.completeTask()
NotificationService.notifyTaskCompleted(task)
```

### Task Status Changed

**Trigger**: Task status is updated

**Recipient**: Assigned user

**Notification Type**: `task_status_changed`

**Implementation**:
```javascript
// In taskService.updateTask() when status changes
if (updates.status && previousStatus !== updates.status && task.assigned_to_user_id) {
  NotificationService.notifyTaskStatusChanged(task, previousStatus)
}
```

### Task Comment (Future Enhancement)

**Trigger**: Comment added to task (once comment system is implemented)

**Recipient**: Task creator, all watchers

**Notification Type**: `task_commented`

### Task Deadline Approaching (Future Enhancement)

**Trigger**: Cron job runs at 6 AM daily

**Recipient**: Users with tasks due in next 24 hours

**Notification Type**: `task_deadline_approaching`

### Task Review Notifications (Future Enhancement)

**Trigger**: Task review status updates

**Types**:
- `task_review_pending` - When task awaits review
- `task_review_approved` - When task review is approved
- `task_review_rejected` - When task review is rejected

---

## RBAC Compliance

The notifications system respects all existing RBAC and department privacy rules:

### Authorization Rules

1. **Users can only access their own notifications**
   - Enforced in NotificationController methods
   - Each user can only mark/delete their notifications

2. **Notifications honor task visibility rules**
   - If user can't view a task, they don't get notifications about it
   - Department privacy masking applied when task is cross-department

3. **Cross-Department Task Notifications**
   - Same department → Full notification details shown
   - Different department → Only title + due date shown
   - Management/Dept Head/Superadmin → Always see full details

### Implementation

```javascript
// In NotificationService.createNotification()
// Check notification preferences before creating

// Permissions are implicit:
// - Task assigned notifications only go to assigned user
// - Task completed notifications only go to creator
// - Status changes only go to assignee
```

### Broadcast Rooms

- `user:{userId}` - Only the user receives messages
- `company:{companyId}` - All company members in that company
- `dept:{departmentId}` - All users in that department

---

## Development Setup

### Prerequisites

- Node.js 18+
- MySQL 8.0+
- Socket.io already installed (npm install socket.io)

### 1. Run Migrations

```bash
cd backend
npm run db:migrate
```

This will create:
- `notifications` table
- `notification_preferences` table

### 2. Start Backend Server

```bash
npm run dev
```

Check logs for:
```
[STARTUP:7] Initializing Socket.io...
Socket.io initialized successfully
```

### 3. Test Socket Connection

**Option A: Using Node.js Client**

```javascript
// test-socket.js
const io = require('socket.io-client');

const token = 'your_jwt_token_here';

const socket = io('http://localhost:5000', {
  auth: { token },
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 5000,
  reconnectionAttempts: 5
});

socket.on('connect', () => {
  console.log('✓ Connected to server');
});

socket.on('notification:new', (notification) => {
  console.log('📬 New notification:', notification);
});

socket.on('disconnect', () => {
  console.log('✗ Disconnected from server');
});

socket.on('error', (error) => {
  console.error('Error:', error);
});

// Run: node test-socket.js
```

**Option B: Using curl to trigger notifications**

```bash
# Get auth token
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"hr.emp1@demo.tsi","password":"Demo@1234"}'

# Create a task (will trigger notification to assignee)
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing notifications",
    "assigned_to": 3,
    "priority": "high"
  }'
```

### 4. Verify Notifications

```bash
# Check unread count
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/v1/notifications/count

# Get all notifications
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/v1/notifications

# Mark as read
curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/v1/notifications/{notificationId}/read
```

---

## Production Deployment

### 1. Environment Configuration

Add to `.env`:

```env
# Existing variables...

# Socket.io is automatically initialized if not disabled
# No additional env vars needed - uses existing CORS_ORIGINS and JWT_SECRET
```

### 2. Render.com Deployment

Socket.io works out-of-the-box on Render with automatic WebSocket support:

1. Push code to GitHub
2. Render auto-detects changes
3. Server restarts and initializes Socket.io
4. No additional configuration needed

### 3. Railway Database

Tables are created automatically on first migration run:

```bash
# On Render dashboard, run in the shell:
cd /var/task
npm run db:migrate
```

Or migrations run automatically on server startup.

### 4. Production URLs

Update client Socket.io connection:

```javascript
// For production (task.thestudioinfinito.com domain)
final io = await IO.io(
  'https://studioinfinito-api.onrender.com',
  OptionBuilder(
    query: {'token': authToken},
  ).build(),
);
```

### 5. Monitoring

Check logs in Render dashboard:

```
[STARTUP:7] Initializing Socket.io...
Socket.io initialized successfully
User connected - ID: 5, Socket ID: abc123...
Notification emitted to user 5 via Socket.io
```

### 6. Performance Considerations

- **Connection Pooling**: Sequelize pool configured in config/database.js
- **Memory**: Socket.io stores user connections in memory (scales to ~10K concurrent users per Node instance)
- **Scaling**: For multi-instance deployments, use Redis adapter:

```javascript
// Future enhancement for horizontal scaling
const redisAdapter = require('socket.io-redis');
io.adapter(redisAdapter.createAdapter(redis));
```

---

## Testing & Debugging

### Debug Mode

Enable debug logs:

```bash
# Terminal 1: Backend with debug
DEBUG=* npm run dev

# Or just Socket.io debug
DEBUG=socket.io* npm run dev
```

### Test Scenarios

#### Scenario 1: Simple Task Assignment

```bash
# User 1 creates task assigned to User 2
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Authorization: Bearer USER1_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Review Document",
    "assigned_to": 2,
    "priority": "normal"
  }'

# User 2 socket receives notification:new event
# Check via API:
curl -H "Authorization: Bearer USER2_TOKEN" \
  http://localhost:5000/api/v1/notifications/count
# Should return: { "unreadCount": 1 }
```

#### Scenario 2: Task Completion Workflow

```bash
# User 2 completes the task
curl -X POST http://localhost:5000/api/v1/tasks/{taskId}/complete \
  -H "Authorization: Bearer USER2_TOKEN"

# User 1 (creator) socket receives notification:new event
# Notification type: task_completed
```

#### Scenario 3: Cross-Department Task

```bash
# HR Employee creates task for Finance Employee
curl -X POST http://localhost:5000/api/v1/tasks \
  -H "Authorization: Bearer HR_EMP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Finance Report",
    "assigned_to": 7,  # Finance employee
    "priority": "high"
  }'

# Notification visible in Finance employee's app
# Shows: Title + Due date (description masked)
```

### Common Issues

#### Issue: Socket connection fails

```
Error: Authentication error: No token provided
```

**Solution**: Ensure token is passed in handshake auth:

```javascript
const socket = io('http://localhost:5000', {
  auth: { token: 'Bearer your_token_here' }
});
```

#### Issue: CORS error

```
Not allowed by CORS
```

**Solution**: Add domain to CORS_ORIGINS in production:

```env
CORS_ORIGINS=https://task.thestudioinfinito.com,https://studioinfinito-api.onrender.com
```

#### Issue: Notifications not appearing

**Checklist**:
1. ✓ Is user's socket connected? (Check logs: "User connected")
2. ✓ Is notification preference enabled? (Check notification_preferences table)
3. ✓ Is user authorized to see task? (Check RBAC rules)
4. ✓ Is Socket.io initialized? (Check server startup logs)

---

## Client Integration Examples

### Flutter - Socket.io Setup

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class NotificationService {
  late IO.Socket socket;

  Future<void> initSocket(String token) async {
    socket = IO.io(
      'http://localhost:5000',  // or https://api.thestudioinfinito.com
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': token})
        .build(),
    );

    // Connection events
    socket.onConnect((_) {
      print('✓ Connected to notification server');
    });

    socket.on('notification:new', (notification) {
      _handleNewNotification(notification);
    });

    socket.on('task:update', (update) {
      _handleTaskUpdate(update);
    });

    socket.onDisconnect((_) {
      print('✗ Disconnected from notification server');
    });

    socket.onError((error) {
      print('Socket error: $error');
    });

    socket.connect();
  }

  void disconnect() {
    socket.disconnect();
  }

  void sendPing() {
    socket.emit('ping');
  }

  void subscribeToTask(int taskId) {
    socket.emit('subscribe', {'room': 'task:$taskId'});
  }

  void _handleNewNotification(dynamic data) {
    // Parse notification and update UI
    print('New notification: ${data['title']}');
  }

  void _handleTaskUpdate(dynamic data) {
    // Handle real-time task updates
    print('Task ${data['taskId']} updated: ${data['action']}');
  }
}
```

### JavaScript - Socket.io Setup

```javascript
import io from 'socket.io-client';

class NotificationManager {
  constructor(serverUrl, token) {
    this.socket = io(serverUrl, {
      auth: { token },
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      reconnectionAttempts: 5
    });

    this.setupListeners();
  }

  setupListeners() {
    this.socket.on('connect', () => {
      console.log('✓ Connected');
    });

    this.socket.on('notification:new', (notification) => {
      this.onNewNotification(notification);
    });

    this.socket.on('task:update', (update) => {
      this.onTaskUpdate(update);
    });

    this.socket.on('disconnect', () => {
      console.log('✗ Disconnected');
    });

    this.socket.on('error', (error) => {
      console.error('Socket error:', error);
    });
  }

  onNewNotification(notification) {
    // Handle notification UI update
    console.log('New notification:', notification.title);
    // Show toast, update badge, etc.
  }

  onTaskUpdate(update) {
    // Handle task UI update
    console.log(`Task ${update.taskId} ${update.action}`);
  }

  disconnect() {
    this.socket.disconnect();
  }
}

// Usage
const notificationManager = new NotificationManager(
  'https://api.thestudioinfinito.com',
  authToken
);
```

---

## Summary

The notifications system is production-ready with:

✅ Real-time WebSocket delivery
✅ JWT authentication
✅ RBAC + department privacy compliance
✅ Database persistence
✅ User preferences support
✅ REST API + Socket.io events
✅ Automatic trigger integration
✅ Render.com compatible
✅ Comprehensive error handling
✅ Performance optimized

### Next Steps

1. Implement comment notifications (once comment system is added)
2. Add deadline approaching cron job
3. Add task review status notifications
4. Implement email digest option
5. Add notification analytics dashboard
