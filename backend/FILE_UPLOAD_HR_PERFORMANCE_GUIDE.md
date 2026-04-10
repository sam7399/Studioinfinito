# File Upload Validation & HR Performance Features Guide

This document provides comprehensive documentation for the newly implemented file upload validation and HR performance tracking features in the Studioinfinito backend.

---

## Table of Contents

1. [File Upload Validation](#file-upload-validation)
2. [HR Performance Features](#hr-performance-features)
3. [API Endpoints](#api-endpoints)
4. [Database Schema](#database-schema)
5. [RBAC Compliance](#rbac-compliance)
6. [Integration Points](#integration-points)
7. [Testing & Verification](#testing--verification)
8. [Troubleshooting](#troubleshooting)

---

## File Upload Validation

### Overview

The file upload validation system provides comprehensive validation and security scanning for all file uploads to tasks. It ensures that only approved file types and sizes are accepted, with built-in malware detection.

### Features

#### 1. File Size Limits by Category

| Category | Maximum Size | Use Case |
|----------|--------------|----------|
| Documents | 5 MB | PDF, Word, Excel, PowerPoint, Text, CSV |
| Images | 10 MB | JPEG, PNG, GIF, WebP, SVG |
| Videos | 50 MB | MP4, MOV, AVI, WebM |
| Archives | 20 MB | ZIP, RAR, 7Z, GZ, TAR |

#### 2. Allowed File Types

**Documents:**
- `application/pdf` (.pdf)
- `application/msword` (.doc)
- `application/vnd.openxmlformats-officedocument.wordprocessingml.document` (.docx)
- `application/vnd.ms-excel` (.xls)
- `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` (.xlsx)
- `application/vnd.ms-powerpoint` (.ppt)
- `application/vnd.openxmlformats-officedocument.presentationml.presentation` (.pptx)
- `text/plain` (.txt)
- `text/csv` (.csv)

**Images:**
- `image/jpeg` (.jpg, .jpeg)
- `image/png` (.png)
- `image/gif` (.gif)
- `image/webp` (.webp)
- `image/svg+xml` (.svg)

**Videos:**
- `video/mp4` (.mp4)
- `video/quicktime` (.mov)
- `video/x-msvideo` (.avi)
- `video/webm` (.webm)

**Archives:**
- `application/zip` (.zip)
- `application/x-rar-compressed` (.rar)
- `application/x-7z-compressed` (.7z)
- `application/gzip` (.gz)

#### 3. Security Features

- **Virus/Malware Scanning**: Checks for executable signatures and suspicious patterns
- **File Type Validation**: Validates both MIME type and extension
- **Unique Filename Generation**: Uses cryptographic hashing for secure filenames
- **Checksum Generation**: SHA-256 checksums for file integrity verification
- **Size Validation**: Enforces category-specific size limits

### Implementation Details

#### FileValidatorService

Location: `src/services/fileValidatorService.js`

Key Methods:

```javascript
// Validate file type
FileValidatorService.validateFileType(file)
// Returns: { valid: boolean, category: string, error?: string }

// Validate file size
FileValidatorService.validateFileSize(file)
// Returns: { valid: boolean, error?: string }

// Scan for malware
await FileValidatorService.scanForMalware(filePath)
// Returns: { safe: boolean, reason?: string }

// Validate and prepare file
await FileValidatorService.validateAndPrepareFile(file)
// Returns: { valid: boolean, metadata: object, error?: string }

// Generate unique filename
FileValidatorService.generateUniqueFilename(originalFilename)
// Returns: string (unique filename with hash)

// Generate checksum
FileValidatorService.generateFileChecksum(filePath)
// Returns: string (SHA-256 hash)
```

#### Multer Configuration

Location: `src/config/multer.js`

- Integrated with FileValidatorService
- Automatic unique filename generation
- File type validation via fileFilter
- Size limit enforcement

#### TaskAttachment Model

Location: `src/models/taskAttachment.js`

Fields:
- `id`: Primary key
- `task_id`: Reference to task
- `uploaded_by_user_id`: Reference to uploader
- `original_name`: Original filename
- `stored_name`: Secure filename on server
- `mime_type`: MIME type of file
- `file_size`: File size in bytes
- `created_at`: Upload timestamp
- `updated_at`: Last modification timestamp

### File Upload Endpoints

All file upload endpoints require authentication.

#### Upload File to Task

```http
POST /api/v1/tasks/:id/attachments
Content-Type: multipart/form-data

file: <binary file data>
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "task_id": 5,
    "uploaded_by_user_id": 2,
    "original_name": "document.pdf",
    "stored_name": "1649876543210-a1b2c3d4e5f6g7h8.pdf",
    "mime_type": "application/pdf",
    "file_size": 102400,
    "created_at": "2026-04-06T10:30:00Z",
    "updated_at": "2026-04-06T10:30:00Z",
    "uploader": {
      "id": 2,
      "name": "John Doe"
    }
  }
}
```

**Error Responses:**
- `400 Bad Request`: No file uploaded or file validation failed
- `404 Not Found`: Task not found
- `413 Payload Too Large`: File exceeds size limit

#### List Attachments for Task

```http
GET /api/v1/tasks/:id/attachments
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "task_id": 5,
      "uploaded_by_user_id": 2,
      "original_name": "document.pdf",
      "stored_name": "1649876543210-a1b2c3d4e5f6g7h8.pdf",
      "mime_type": "application/pdf",
      "file_size": 102400,
      "created_at": "2026-04-06T10:30:00Z",
      "updated_at": "2026-04-06T10:30:00Z",
      "uploader": {
        "id": 2,
        "name": "John Doe"
      }
    }
  ]
}
```

#### Download Attachment

```http
GET /api/v1/tasks/:id/attachments/:attachmentId/download
```

**Response:**
- Binary file content with appropriate content-type header
- Content-Disposition header set to `attachment; filename="<original_name>"`

#### Delete Attachment

```http
DELETE /api/v1/tasks/:id/attachments/:attachmentId
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Attachment deleted"
}
```

---

## HR Performance Features

### Overview

The HR performance features provide comprehensive employee and department performance tracking, metrics calculation, and reporting capabilities. These features automatically calculate performance metrics when tasks are completed and provide insights for HR decision-making.

### Key Features

#### 1. Performance Models

**TaskMetrics**
- Tracks individual user performance for a specific period
- Fields: tasks_completed, tasks_on_time, tasks_late, average_completion_days, average_quality_score, rejection_count
- Calculated monthly

**DepartmentMetrics**
- Tracks department-level performance
- Fields: total_tasks, completed_tasks, on_time_percentage, completion_percentage, average_time_to_complete, average_quality_score
- Calculated monthly

**EmployeePerformance**
- Long-term performance record for employees
- Fields: overall_rating, task_completion_rate, on_time_completion_rate, average_quality_score, strengths, weaknesses, improvements_areas, achievements, evaluation_notes
- Updated when tasks are reviewed

#### 2. Automatic Performance Tracking

When a task is reviewed and finalized:
1. Task quality score is recorded
2. TaskMetrics for the current month are updated
3. EmployeePerformance record is updated with new quality score
4. All calculations are done asynchronously (non-blocking)

#### 3. Performance Calculations

**On-Time Completion Rate:**
```
(Tasks completed by due date / Total completed tasks) * 100
```

**Task Completion Rate:**
```
(Total completed tasks / Total assigned tasks) * 100
```

**Overall Rating:**
```
(Quality Score * 0.6) + (On-Time Rate * 0.4)
```

**Average Completion Days:**
```
Sum of (Completion Date - Created Date) / Number of tasks
```

### PerformanceService

Location: `src/services/performanceService.js`

Key Methods:

```javascript
// Calculate user metrics for a period
await PerformanceService.calculateUserMetrics(userId, startDate, endDate)

// Calculate department metrics
await PerformanceService.calculateDepartmentMetrics(departmentId, month, year)

// Get detailed performance report
await PerformanceService.getPerformanceReport(userId)

// Get top performers in department
await PerformanceService.getTopPerformers(departmentId, limit)

// Generate company-wide HR report
await PerformanceService.generateHRReport(month, year)

// Get performance trends over time
await PerformanceService.getPerformanceTrends(userId, months)

// Update employee performance record
await PerformanceService.updateEmployeePerformance(userId, departmentId, performanceData)

// Calculate performances for all users in department
await PerformanceService.calculateDepartmentPerformances(departmentId, month, year)
```

---

## API Endpoints

### HR Dashboard Endpoints

All HR endpoints require authentication and appropriate RBAC role (Management, Department Head, Manager, or Superadmin for most endpoints).

#### 1. Main HR Dashboard

```http
GET /api/v1/hr/dashboard?month=4&year=2026
```

**Parameters:**
- `month` (optional): Month number (1-12), defaults to current month
- `year` (optional): Year, defaults to current year

**Response:**
```json
{
  "success": true,
  "data": {
    "month": 4,
    "year": 2026,
    "generated_at": "2026-04-06T10:30:00Z",
    "company_summary": {
      "total_tasks": 150,
      "completed_tasks": 120,
      "on_time_tasks": 108,
      "completion_rate": 80,
      "on_time_rate": 90,
      "total_employees": 18,
      "department_count": 4
    },
    "departments": [
      {
        "id": 1,
        "name": "Human Resources",
        "total_tasks": 40,
        "completed_tasks": 35,
        "on_time_tasks": 32,
        "late_tasks": 3,
        "on_time_percentage": 91.43,
        "completion_percentage": 87.5,
        "average_time_to_complete": 3.2,
        "average_quality_score": 4.5,
        "team_size": 4
      }
      // ... more departments
    ]
  }
}
```

#### 2. Performance Summary

```http
GET /api/v1/hr/performance-summary?month=4&year=2026
```

**Response:**
```json
{
  "success": true,
  "data": {
    "period": "4/2026",
    "generated_at": "2026-04-06T10:30:00Z",
    "company_summary": { ... },
    "top_departments": [
      { "id": 1, "name": "HR", "completion_percentage": 87.5 },
      // ... top 3 departments by completion rate
    ]
  }
}
```

#### 3. Department Performance

```http
GET /api/v1/hr/department-performance?department_id=1&month=4&year=2026
```

**Parameters:**
- `department_id` (required): Department ID
- `month` (optional): Month number
- `year` (optional): Year

**Response:**
```json
{
  "success": true,
  "data": {
    "metrics": {
      "id": 1,
      "department_id": 1,
      "total_tasks": 40,
      // ... all department metrics
    },
    "employee_performances": [
      {
        "user_id": 3,
        "user_name": "Rahul Singh",
        "task_completion_rate": 100,
        "on_time_completion_rate": 95.5,
        "average_quality_score": 4.5,
        "overall_rating": 4.7
      }
      // ... more employees
    ]
  }
}
```

#### 4. Individual Employee Performance

```http
GET /api/v1/hr/employee-performance/:id
```

**Parameters:**
- `id` (path, required): User ID

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 3,
      "name": "Rahul Singh",
      "email": "hr.emp1@demo.tsi",
      "emp_code": "DEMO-HR-003",
      "department": {
        "id": 1,
        "name": "Human Resources"
      }
    },
    "performance": {
      "id": 1,
      "user_id": 3,
      "overall_rating": 4.7,
      "task_completion_rate": 100,
      "on_time_completion_rate": 95.5,
      "average_quality_score": 4.5,
      "strengths": ["attention to detail", "deadline management"],
      "weaknesses": [],
      "last_evaluated": "2026-04-01T10:00:00Z"
    },
    "metrics": [
      {
        "user_id": 3,
        "tasks_completed": 10,
        "tasks_on_time": 9,
        "tasks_late": 1,
        "average_completion_days": 2.3,
        "average_quality_score": 4.5,
        "period_start": "2026-04-01",
        "period_end": "2026-04-30"
      }
    ],
    "recent_tasks": [
      {
        "id": 5,
        "title": "Complete HR Report",
        "status": "finalized",
        "priority": "high",
        "due_date": "2026-04-05",
        "created_at": "2026-03-28",
        "updated_at": "2026-04-04"
      }
    ]
  }
}
```

#### 5. Performance Trends

```http
GET /api/v1/hr/performance-trends?user_id=3&months=6
```

**Parameters:**
- `user_id` (optional): User ID (defaults to current user)
- `months` (optional): Number of months to retrieve (default: 6, max: 24)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "user_id": 3,
      "tasks_completed": 8,
      "tasks_on_time": 7,
      "tasks_late": 1,
      "average_completion_days": 2.5,
      "average_quality_score": 4.2,
      "period_start": "2025-11-01",
      "period_end": "2025-11-30"
    },
    // ... more months in chronological order
  ]
}
```

#### 6. Top Performers

```http
GET /api/v1/hr/top-performers?department_id=1&limit=10
```

**Parameters:**
- `department_id` (required): Department ID
- `limit` (optional): Number of performers to retrieve (default: 10, max: 100)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "user_id": 3,
      "department_id": 1,
      "overall_rating": 4.7,
      "task_completion_rate": 100,
      "on_time_completion_rate": 95.5,
      "average_quality_score": 4.5,
      "user": {
        "id": 3,
        "name": "Rahul Singh",
        "emp_code": "DEMO-HR-003",
        "email": "hr.emp1@demo.tsi"
      },
      "department": {
        "id": 1,
        "name": "Human Resources"
      }
    }
    // ... more top performers
  ]
}
```

#### 7. Generate Performance Report

```http
POST /api/v1/hr/performance-report
Content-Type: application/json

{
  "month": 4,
  "year": 2026,
  "format": "json"
}
```

**Parameters (Body):**
- `month` (required): Month number (1-12)
- `year` (required): Year
- `format` (optional): 'json' or 'csv' (default: 'json')

**Response:**
- If format is 'json': Returns JSON response with full report data
- If format is 'csv' or any other: Downloads file as attachment

---

## Database Schema

### TaskMetrics Table

```sql
CREATE TABLE task_metrics (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  tasks_completed INT DEFAULT 0,
  tasks_on_time INT DEFAULT 0,
  tasks_late INT DEFAULT 0,
  tasks_pending_review INT DEFAULT 0,
  average_completion_days DECIMAL(10, 2),
  average_quality_score DECIMAL(3, 2),
  rejection_count INT DEFAULT 0,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_period (period_start, period_end)
);
```

### DepartmentMetrics Table

```sql
CREATE TABLE department_metrics (
  id INT PRIMARY KEY AUTO_INCREMENT,
  department_id INT NOT NULL,
  total_tasks INT DEFAULT 0,
  completed_tasks INT DEFAULT 0,
  on_time_tasks INT DEFAULT 0,
  late_tasks INT DEFAULT 0,
  on_time_percentage DECIMAL(5, 2),
  completion_percentage DECIMAL(5, 2),
  average_time_to_complete DECIMAL(10, 2),
  average_quality_score DECIMAL(3, 2),
  team_size INT DEFAULT 0,
  month INT NOT NULL,
  year INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  INDEX idx_department (department_id),
  INDEX idx_period (month, year)
);
```

### EmployeePerformance Table

```sql
CREATE TABLE employee_performance (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL UNIQUE,
  department_id INT NOT NULL,
  overall_rating DECIMAL(3, 2),
  task_completion_rate DECIMAL(5, 2),
  on_time_completion_rate DECIMAL(5, 2),
  average_quality_score DECIMAL(3, 2),
  strengths JSON,
  weaknesses JSON,
  improvement_areas JSON,
  achievements JSON,
  last_evaluated TIMESTAMP,
  evaluation_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_department (department_id),
  INDEX idx_rating (overall_rating)
);
```

---

## RBAC Compliance

### File Upload Access

**Who can upload files to a task?**
- Task assignee (can upload to their own tasks)
- Task creator (can upload to tasks they created)
- Managers and above (can upload to any task in their scope)
- Superadmin (can upload to any task)

**Department Privacy:**
- Files are part of tasks, so task visibility rules apply
- Cross-department task visibility: title and due date only (unless manager/superadmin)

### Performance Data Access

**Who can access HR dashboard and reports?**
- Superadmin: Full access to all performance data
- Management: Full access to all performance data
- Department Head: Access to own department performance only
- Manager: Access to own team performance only
- Employee: Can only see their own performance

**Access Control Methods:**
```javascript
// Check if user can access performance data
RBACService.canAccessPerformanceData(user)

// Check if user can access specific employee's performance
RBACService.canAccessEmployeePerformance(requestingUser, targetUserId)
```

---

## Integration Points

### 1. Task Service Integration

When a task is reviewed and finalized:

```javascript
// In TaskService.submitReview()
// Performance metrics are automatically updated:
- PerformanceService.calculateUserMetrics()
- PerformanceService.updateEmployeePerformance()
```

### 2. Notification Integration

Performance-related events can trigger notifications:
- Task completion notifications
- Performance milestones (top performer achievement)
- Low performance alerts (for managers)

### 3. File Upload Integration

Files uploaded to tasks trigger:
- File validation
- Malware scanning
- Metadata storage in TaskAttachment model

### 4. Task Review Integration

When tasks are reviewed:
- Quality scores are recorded
- Performance metrics are updated
- Trends are calculated

---

## Testing & Verification

### Database Migrations

Run migrations to create new tables:

```bash
cd /home/ubuntu/Studioinfinito/backend
npm run db:migrate
```

Migrations included:
- `20240101000022-create-task-metrics.js`
- `20240101000023-create-department-metrics.js`
- `20240101000024-create-employee-performance.js`

### Manual Testing - File Upload

```bash
# Upload a PDF file to task 1
curl -X POST http://localhost:5000/api/v1/tasks/1/attachments \
  -H "Authorization: Bearer <token>" \
  -F "file=@/path/to/document.pdf"

# List attachments for task 1
curl http://localhost:5000/api/v1/tasks/1/attachments \
  -H "Authorization: Bearer <token>"

# Download attachment 1
curl http://localhost:5000/api/v1/tasks/1/attachments/1/download \
  -H "Authorization: Bearer <token>" \
  -o document.pdf
```

### Manual Testing - HR Dashboard

```bash
# Get HR dashboard for current month
curl http://localhost:5000/api/v1/hr/dashboard \
  -H "Authorization: Bearer <management_token>"

# Get employee performance
curl http://localhost:5000/api/v1/hr/employee-performance/3 \
  -H "Authorization: Bearer <hr_token>"

# Get top performers in HR department
curl "http://localhost:5000/api/v1/hr/top-performers?department_id=1" \
  -H "Authorization: Bearer <management_token>"

# Generate HR report
curl -X POST http://localhost:5000/api/v1/hr/performance-report \
  -H "Authorization: Bearer <management_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "month": 4,
    "year": 2026,
    "format": "json"
  }'
```

### Database Verification

```sql
-- Check task metrics
SELECT * FROM task_metrics;

-- Check department metrics
SELECT * FROM department_metrics;

-- Check employee performance
SELECT * FROM employee_performance;

-- Check task attachments
SELECT * FROM task_attachments;

-- Verify metrics for a specific user
SELECT * FROM task_metrics WHERE user_id = 3 ORDER BY period_start DESC;

-- Verify department metrics
SELECT * FROM department_metrics WHERE department_id = 1 ORDER BY year DESC, month DESC;
```

---

## Troubleshooting

### File Upload Issues

**Issue: File upload returns "File type not allowed"**
- Verify the file MIME type is in the allowed list
- Check that the file extension matches the MIME type
- Ensure the file is not corrupted

**Issue: File upload returns "File size exceeds limit"**
- Check the file category in FileValidatorService.ALLOWED_FILE_TYPES
- Verify the actual file size vs. the limit for that category
- For documents: max 5MB, images: max 10MB, videos: max 50MB

**Issue: Malware scanning fails**
- This is a non-blocking error; the file is still uploaded with a warning
- Check logs for detailed error: `logs/error-*.log`

### Performance Metrics Issues

**Issue: Performance metrics not updating**
- Verify the task is finalized (status = 'finalized')
- Check that TaskService imports PerformanceService
- Verify database migrations have run
- Check logs for async performance update errors

**Issue: HR dashboard returns no data**
- Verify the current user has appropriate RBAC role (Manager, Dept Head, Management, Superadmin)
- Ensure there are completed tasks in the requested month/year
- Check that TaskMetrics and DepartmentMetrics tables have data

**Issue: Employee performance not showing ratings**
- Verify the task was reviewed with quality_score
- Check that EmployeePerformance record was created for the user/department
- Ensure the last_evaluated timestamp is recent

### RBAC Issues

**Issue: User gets "Access denied" for performance data**
- Verify user role: only Management/Dept Head/Manager/Superadmin can access HR dashboard
- For employee performance: user can see their own, managers can see team, etc.
- Check RBACService.canAccessPerformanceData() method

**Issue: Cross-department task visibility issues**
- File uploads follow task visibility rules
- Check RBACService.maskTask() method for visibility masking
- Managers from other departments should see only title and due date

### Performance & Optimization

**Optimize performance metrics queries:**
- Use indexes on period_start, period_end, user_id, department_id
- Consider caching monthly metrics (they don't change often)
- Batch calculate metrics during off-hours (cron job)

**Optimize file storage:**
- Regular cleanup of old/deleted attachments
- Monitor disk usage in uploads/tasks directory
- Consider cloud storage integration (S3, etc.) in future

---

## Future Enhancements

1. **Advanced Malware Scanning**: Integrate with ClamAV or Virustotal API
2. **Cloud Storage**: Support S3, Google Cloud Storage, Azure Blob
3. **Performance Notifications**: Automated alerts for low performers
4. **Trend Analysis**: Predictive analytics for performance forecasting
5. **Custom Performance Metrics**: Allow departments to define custom metrics
6. **Performance Export**: PDF, Excel, detailed reports
7. **Performance Analytics**: Charts, graphs, dashboards
8. **Achievement Badges**: Gamification for high performers
9. **Peer Reviews**: 360-degree feedback system
10. **Performance Improvement Plans**: Track improvement initiatives

---

## Support & Maintenance

For issues or questions:
1. Check logs: `/home/ubuntu/Studioinfinito/backend/logs/`
2. Review this guide: All common issues and solutions are documented
3. Check database: SQL queries provided for verification
4. Review code: Services and controllers are well-commented

---

*Last Updated: April 6, 2026*
*Version: 1.0.0*
