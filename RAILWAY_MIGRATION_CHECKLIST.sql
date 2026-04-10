-- ═════════════════════════════════════════════════════════════════════════════
-- RAILWAY DATABASE MIGRATION CHECKLIST
-- ═════════════════════════════════════════════════════════════════════════════
--
-- Instructions:
-- 1. Go to: https://railway.app/dashboard
-- 2. Click your project (Studio Infinito)
-- 3. Click MySQL service
-- 4. Click "Plugins" or "Query" or "Web Console"
-- 5. Copy-paste each script below ONE AT A TIME
-- 6. Click Execute or Run
-- 7. Watch for success message or errors
-- 8. Move to next script when current one completes
--
-- If you see "Query OK" = SUCCESS
-- If you see "Error" = Problem (check error message)
--
-- ═════════════════════════════════════════════════════════════════════════════

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 1: USE DATABASE                                                 ┃
-- ┃ Creates or selects the studio_infinito database                           ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE DATABASE IF NOT EXISTS studio_infinito CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE studio_infinito;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 2: CREATE COMPANIES TABLE                                       ┃
-- ┃ Stores company/organization information                                   ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS companies (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  location VARCHAR(255),
  industry VARCHAR(100),
  phone VARCHAR(20),
  email VARCHAR(255),
  website VARCHAR(255),
  subscription_tier VARCHAR(50) DEFAULT 'free',
  max_users INT DEFAULT 10,
  max_storage_gb INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_name (name),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 3: CREATE DEPARTMENTS TABLE                                     ┃
-- ┃ Stores department information within companies                            ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS departments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  budget DECIMAL(15, 2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  UNIQUE KEY uk_dept_company (company_id, name),
  INDEX idx_company_id (company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 4: CREATE USERS TABLE                                           ┃
-- ┃ Stores user/employee information                                          ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT NOT NULL,
  department_id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  username VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  emp_code VARCHAR(50),
  phone VARCHAR(20),
  designation VARCHAR(100),
  profile_picture_url TEXT,
  role ENUM('super_admin', 'management', 'department_head', 'manager', 'employee') DEFAULT 'employee',
  reports_to_id INT,
  is_active BOOLEAN DEFAULT TRUE,
  last_login DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE RESTRICT,
  FOREIGN KEY (reports_to_id) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uk_email_company (email, company_id),
  UNIQUE KEY uk_username_company (username, company_id),
  UNIQUE KEY uk_emp_code (emp_code),
  INDEX idx_company_id (company_id),
  INDEX idx_department_id (department_id),
  INDEX idx_role (role),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 5: CREATE TASKS TABLE                                           ┃
-- ┃ Stores task information with assignment and approval workflow             ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT NOT NULL,
  creator_id INT NOT NULL,
  assigned_to_id INT,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status ENUM('open', 'in_progress', 'in_review', 'completed', 'archived') DEFAULT 'open',
  priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
  target_date DATE,
  completion_date DATE,
  attachments_count INT DEFAULT 0,
  
  approval_status ENUM('pending', 'approved', 'rejected') NULL,
  approver_id INT NULL,
  approval_comments TEXT,
  approval_date DATE,
  rejection_reason TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE RESTRICT,
  FOREIGN KEY (assigned_to_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_company_id (company_id),
  INDEX idx_creator_id (creator_id),
  INDEX idx_assigned_to_id (assigned_to_id),
  INDEX idx_status (status),
  INDEX idx_approval_status (approval_status),
  INDEX idx_approver_id (approver_id),
  INDEX idx_target_date (target_date),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 6: CREATE TASK_ACTIVITIES TABLE                                 ┃
-- ┃ Logs all activities (actions) on tasks for audit trail                    ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS task_activities (
  id INT AUTO_INCREMENT PRIMARY KEY,
  task_id INT NOT NULL,
  actor_user_id INT NOT NULL,
  action ENUM('created', 'updated', 'assigned', 'status_changed', 'priority_changed', 'completed', 'reopened', 'commented', 'attachment_added', 'submitted_for_approval', 'rejected') NOT NULL,
  description TEXT,
  old_value VARCHAR(255),
  new_value VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE RESTRICT,
  INDEX idx_task_id (task_id),
  INDEX idx_actor_user_id (actor_user_id),
  INDEX idx_action (action),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 7: CREATE TASK_APPROVALS TABLE                                  ┃
-- ┃ Audit trail for manager approval workflow                                 ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS task_approvals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  task_id INT NOT NULL,
  approver_id INT NOT NULL,
  status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
  comments TEXT,
  reason TEXT,
  submitted_at DATETIME,
  reviewed_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE RESTRICT,
  INDEX idx_task_id (task_id),
  INDEX idx_approver_id (approver_id),
  INDEX idx_status (status),
  INDEX idx_task_approver (task_id, approver_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 8: CREATE NOTIFICATIONS TABLE                                   ┃
-- ┃ Stores real-time notifications for users                                  ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  task_id INT,
  type ENUM('task_assigned', 'task_completed', 'task_status_changed', 'task_approval_pending', 'task_approval_approved', 'task_approval_rejected', 'task_comment', 'task_deadline_approaching', 'task_review_pending', 'task_review_approved', 'task_review_rejected') NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  metadata JSON,
  read BOOLEAN DEFAULT FALSE,
  read_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_task_id (task_id),
  INDEX idx_type (type),
  INDEX idx_user_read (user_id, read),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 9: CREATE NOTIFICATION_PREFERENCES TABLE                        ┃
-- ┃ User preferences for which notifications they receive                     ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS notification_preferences (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  task_assigned BOOLEAN DEFAULT TRUE,
  task_completed BOOLEAN DEFAULT TRUE,
  task_commented BOOLEAN DEFAULT TRUE,
  task_deadline_approaching BOOLEAN DEFAULT TRUE,
  task_status_changed BOOLEAN DEFAULT TRUE,
  task_review_pending BOOLEAN DEFAULT TRUE,
  task_review_approved BOOLEAN DEFAULT TRUE,
  task_review_rejected BOOLEAN DEFAULT TRUE,
  task_approval_pending BOOLEAN DEFAULT TRUE,
  task_approval_approved BOOLEAN DEFAULT TRUE,
  task_approval_rejected BOOLEAN DEFAULT TRUE,
  email_notifications BOOLEAN DEFAULT TRUE,
  push_notifications BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 10: CREATE TASK_METRICS TABLE                                   ┃
-- ┃ Tracks monthly performance metrics for tasks                              ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS task_metrics (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  month VARCHAR(7),
  total_tasks INT DEFAULT 0,
  completed_tasks INT DEFAULT 0,
  overdue_tasks INT DEFAULT 0,
  avg_completion_time INT,
  quality_score DECIMAL(3, 2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_month (month),
  UNIQUE KEY uk_user_month (user_id, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 11: CREATE DEPARTMENT_METRICS TABLE                             ┃
-- ┃ Tracks department-level performance metrics                               ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS department_metrics (
  id INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT NOT NULL,
  month VARCHAR(7),
  total_tasks INT DEFAULT 0,
  completed_tasks INT DEFAULT 0,
  overdue_tasks INT DEFAULT 0,
  avg_quality_score DECIMAL(3, 2),
  employee_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  INDEX idx_department_id (department_id),
  INDEX idx_month (month),
  UNIQUE KEY uk_dept_month (department_id, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ MIGRATION 12: CREATE EMPLOYEE_PERFORMANCE TABLE                           ┃
-- ┃ Long-term performance records for employees                               ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CREATE TABLE IF NOT EXISTS employee_performance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  overall_quality_rating DECIMAL(3, 2) DEFAULT 0,
  overall_rating DECIMAL(3, 2) DEFAULT 0,
  total_tasks_completed INT DEFAULT 0,
  total_on_time INT DEFAULT 0,
  on_time_percentage DECIMAL(5, 2) DEFAULT 0,
  avg_quality_score DECIMAL(3, 2) DEFAULT 0,
  total_overdue INT DEFAULT 0,
  review_count INT DEFAULT 0,
  last_updated DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_overall_rating (overall_rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Expected: Query OK

-- ═════════════════════════════════════════════════════════════════════════════
-- ✅ ALL TABLE MIGRATIONS COMPLETE!
-- ═════════════════════════════════════════════════════════════════════════════
--
-- Summary:
-- ✅ 12 tables created successfully
-- ✅ All relationships set up
-- ✅ All indexes created
--
-- What's Next: Seed demo data
--
-- ═════════════════════════════════════════════════════════════════════════════
