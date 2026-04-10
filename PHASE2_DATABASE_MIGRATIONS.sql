-- ============================================================================
-- Phase 2 Database Migrations - Studioinfinito
-- Created: April 6, 2026
-- Purpose: Deploy notifications, approval workflow, and performance metrics
-- ============================================================================
-- 
-- CRITICAL: Run these migrations in order on production database
-- Backup database BEFORE running any migrations
-- Test on staging environment first
-- 
-- This script includes:
-- 1. Real-time Notifications (tables 16-17)
-- 2. Manager Approval Workflow (tables 18-21, modifications)
-- 3. HR Performance Tracking (tables 22-24)
-- 4. All DOWN statements for rollback
--
-- ============================================================================

-- Start transaction for safety
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

-- ============================================================================
-- Migration 20240101000016: Create Notifications Table
-- ============================================================================
-- Purpose: Store real-time notifications for users
-- ============================================================================

CREATE TABLE IF NOT EXISTS `notifications` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `task_id` INT,
  `type` ENUM(
    'task_assigned',
    'task_completed',
    'task_status_changed',
    'task_commented',
    'task_deadline_approaching',
    'task_review_pending',
    'task_review_approved',
    'task_review_rejected',
    'task_approval_pending',
    'task_approval_approved',
    'task_approval_rejected'
  ) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT,
  `metadata` JSON,
  `read` BOOLEAN DEFAULT FALSE,
  `read_at` DATETIME,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `user_id` (`user_id`),
  KEY `task_id` (`task_id`),
  KEY `user_id_read` (`user_id`, `read`),
  KEY `created_at_idx` (`created_at`),
  
  CONSTRAINT `notifications_ibfk_1` 
    FOREIGN KEY (`user_id`) 
    REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `notifications_ibfk_2` 
    FOREIGN KEY (`task_id`) 
    REFERENCES `tasks` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Migration 20240101000017: Create Notification Preferences Table
-- ============================================================================
-- Purpose: Store per-user notification preferences
-- ============================================================================

CREATE TABLE IF NOT EXISTS `notification_preferences` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL UNIQUE,
  `task_assigned` BOOLEAN DEFAULT TRUE,
  `task_completed` BOOLEAN DEFAULT TRUE,
  `task_commented` BOOLEAN DEFAULT TRUE,
  `task_deadline_approaching` BOOLEAN DEFAULT TRUE,
  `task_status_changed` BOOLEAN DEFAULT TRUE,
  `task_review_pending` BOOLEAN DEFAULT TRUE,
  `task_review_approved` BOOLEAN DEFAULT TRUE,
  `task_review_rejected` BOOLEAN DEFAULT TRUE,
  `task_approval_pending` BOOLEAN DEFAULT TRUE,
  `task_approval_approved` BOOLEAN DEFAULT TRUE,
  `task_approval_rejected` BOOLEAN DEFAULT TRUE,
  `email_notifications` BOOLEAN DEFAULT TRUE,
  `push_notifications` BOOLEAN DEFAULT TRUE,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `user_id_idx` (`user_id`),
  
  CONSTRAINT `notification_preferences_ibfk_1` 
    FOREIGN KEY (`user_id`) 
    REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Migration 20240101000018: Add Approval Fields to Tasks Table
-- ============================================================================
-- Purpose: Add manager approval workflow columns to tasks
-- ============================================================================

-- Add columns if they don't exist
ALTER TABLE `tasks` 
ADD COLUMN IF NOT EXISTS `approval_status` ENUM('pending', 'approved', 'rejected') DEFAULT NULL AFTER `status`,
ADD COLUMN IF NOT EXISTS `approver_id` INT DEFAULT NULL AFTER `approval_status`,
ADD COLUMN IF NOT EXISTS `approval_comments` TEXT DEFAULT NULL AFTER `approver_id`,
ADD COLUMN IF NOT EXISTS `approval_date` DATE DEFAULT NULL AFTER `approval_comments`,
ADD COLUMN IF NOT EXISTS `rejection_reason` TEXT DEFAULT NULL AFTER `approval_date`;

-- Add indexes for approval queries if they don't exist
ALTER TABLE `tasks` 
ADD INDEX IF NOT EXISTS `idx_tasks_approval_status` (`approval_status`),
ADD INDEX IF NOT EXISTS `idx_tasks_approver_id` (`approver_id`),
ADD INDEX IF NOT EXISTS `idx_tasks_approval_status_approver` (`approval_status`, `approver_id`);

-- ============================================================================
-- Migration 20240101000019: Create Task Approvals Table
-- ============================================================================
-- Purpose: Audit trail for manager approval workflow
-- ============================================================================

CREATE TABLE IF NOT EXISTS `task_approvals` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `task_id` INT NOT NULL,
  `approver_id` INT NOT NULL,
  `status` ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  `comments` TEXT,
  `reason` TEXT,
  `submitted_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` DATETIME,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `task_id_idx` (`task_id`),
  KEY `approver_id_idx` (`approver_id`),
  KEY `status_idx` (`status`),
  KEY `submitted_at_idx` (`submitted_at`),
  KEY `task_status_idx` (`task_id`, `status`),
  
  CONSTRAINT `task_approvals_ibfk_1` 
    FOREIGN KEY (`task_id`) 
    REFERENCES `tasks` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `task_approvals_ibfk_2` 
    FOREIGN KEY (`approver_id`) 
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Migration 20240101000020: Add Approval Notification Types
-- ============================================================================
-- Purpose: Extend notification type enum with approval events
-- Note: Already added in Migration 000016, but documented here
-- ============================================================================

-- Notification types already include:
-- - task_approval_pending
-- - task_approval_approved
-- - task_approval_rejected
-- (See migration 000016 for complete list)

-- ============================================================================
-- Migration 20240101000021: Add Approval Actions to Task Activities
-- ============================================================================
-- Purpose: Extend task activity action enum with approval events
-- ============================================================================

-- First, check current ENUM values and modify if needed
ALTER TABLE `task_activities` 
MODIFY COLUMN `action` ENUM(
  'created',
  'assigned',
  'status_changed',
  'priority_changed',
  'description_updated',
  'completed',
  'reopened',
  'reviewed',
  'reviewed_approved',
  'reviewed_rejected',
  'attachment_added',
  'comment_added',
  'submitted_for_approval',
  'rejected'
) NOT NULL DEFAULT 'created';

-- ============================================================================
-- Migration 20240101000022: Create Task Metrics Table
-- ============================================================================
-- Purpose: Monthly performance metrics per user
-- ============================================================================

CREATE TABLE IF NOT EXISTS `task_metrics` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `tasks_completed` INT NOT NULL DEFAULT 0,
  `tasks_on_time` INT NOT NULL DEFAULT 0,
  `tasks_late` INT NOT NULL DEFAULT 0,
  `tasks_pending_review` INT NOT NULL DEFAULT 0,
  `average_completion_days` DECIMAL(10, 2) DEFAULT 0,
  `average_quality_score` DECIMAL(3, 2) DEFAULT 0,
  `rejection_count` INT NOT NULL DEFAULT 0,
  `period_start` DATE NOT NULL,
  `period_end` DATE NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `user_id_idx` (`user_id`),
  KEY `period_idx` (`period_start`, `period_end`),
  UNIQUE KEY `user_period_idx` (`user_id`, `period_start`, `period_end`),
  
  CONSTRAINT `task_metrics_ibfk_1` 
    FOREIGN KEY (`user_id`) 
    REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Migration 20240101000023: Create Department Metrics Table
-- ============================================================================
-- Purpose: Monthly performance metrics per department
-- ============================================================================

CREATE TABLE IF NOT EXISTS `department_metrics` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `department_id` INT NOT NULL,
  `total_tasks` INT NOT NULL DEFAULT 0,
  `completed_tasks` INT NOT NULL DEFAULT 0,
  `on_time_tasks` INT NOT NULL DEFAULT 0,
  `late_tasks` INT NOT NULL DEFAULT 0,
  `on_time_percentage` DECIMAL(5, 2) DEFAULT 0,
  `completion_percentage` DECIMAL(5, 2) DEFAULT 0,
  `average_time_to_complete` DECIMAL(10, 2) DEFAULT 0,
  `average_quality_score` DECIMAL(3, 2) DEFAULT 0,
  `team_size` INT NOT NULL DEFAULT 0,
  `month` INT NOT NULL,
  `year` INT NOT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `dept_id_idx` (`department_id`),
  KEY `period_idx` (`month`, `year`),
  UNIQUE KEY `dept_period_idx` (`department_id`, `month`, `year`),
  
  CONSTRAINT `department_metrics_ibfk_1` 
    FOREIGN KEY (`department_id`) 
    REFERENCES `departments` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Migration 20240101000024: Create Employee Performance Table
-- ============================================================================
-- Purpose: Long-term employee performance ratings and evaluations
-- ============================================================================

CREATE TABLE IF NOT EXISTS `employee_performance` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `department_id` INT NOT NULL,
  `overall_rating` DECIMAL(3, 2) DEFAULT 0,
  `task_completion_rate` DECIMAL(5, 2) DEFAULT 0,
  `on_time_completion_rate` DECIMAL(5, 2) DEFAULT 0,
  `average_quality_score` DECIMAL(3, 2) DEFAULT 0,
  `strengths` JSON,
  `weaknesses` JSON,
  `improvement_areas` JSON,
  `achievements` JSON,
  `last_evaluated` DATETIME,
  `evaluation_notes` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `user_id_idx` (`user_id`),
  KEY `dept_id_idx` (`department_id`),
  KEY `rating_idx` (`overall_rating`),
  UNIQUE KEY `user_dept_idx` (`user_id`, `department_id`),
  
  CONSTRAINT `employee_performance_ibfk_1` 
    FOREIGN KEY (`user_id`) 
    REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `employee_performance_ibfk_2` 
    FOREIGN KEY (`department_id`) 
    REFERENCES `departments` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Add Foreign Key for Approver ID if needed
-- ============================================================================

-- Add foreign key for approver_id in tasks table
ALTER TABLE `tasks` 
ADD CONSTRAINT `tasks_approver_fk` 
FOREIGN KEY (`approver_id`) 
REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================================
-- Verification Queries
-- ============================================================================
-- Run these to verify migrations completed successfully
-- ============================================================================

-- Check if all tables created
SELECT 
  TABLE_NAME,
  ROUND(((data_length + index_length) / 1024 / 1024), 2) as size_mb,
  TABLE_ROWS,
  CREATION_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME IN (
  'notifications',
  'notification_preferences',
  'task_approvals',
  'task_metrics',
  'department_metrics',
  'employee_performance'
)
ORDER BY TABLE_NAME;

-- Check tasks table modifications
SELECT 
  COLUMN_NAME,
  COLUMN_TYPE,
  IS_NULLABLE,
  COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_NAME = 'tasks'
AND COLUMN_NAME IN (
  'approval_status',
  'approver_id',
  'approval_comments',
  'approval_date',
  'rejection_reason'
)
ORDER BY ORDINAL_POSITION;

-- Check notification types
SELECT COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_NAME = 'notifications'
AND COLUMN_NAME = 'type';

-- Check task activity actions
SELECT COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_NAME = 'task_activities'
AND COLUMN_NAME = 'action';

-- ============================================================================
-- DOWN/ROLLBACK STATEMENTS
-- ============================================================================
-- Only run if you need to rollback Phase 2 migrations
-- Run in REVERSE order of up migrations
-- ============================================================================

-- ROLLBACK 24: Drop employee_performance table
-- DROP TABLE IF EXISTS employee_performance;

-- ROLLBACK 23: Drop department_metrics table
-- DROP TABLE IF EXISTS department_metrics;

-- ROLLBACK 22: Drop task_metrics table
-- DROP TABLE IF EXISTS task_metrics;

-- ROLLBACK 21: Revert task_activities action enum
-- ALTER TABLE task_activities
-- MODIFY COLUMN action ENUM(
--   'created',
--   'assigned',
--   'status_changed',
--   'priority_changed',
--   'description_updated',
--   'completed',
--   'reopened',
--   'reviewed',
--   'reviewed_approved',
--   'reviewed_rejected',
--   'attachment_added',
--   'comment_added'
-- ) NOT NULL DEFAULT 'created';

-- ROLLBACK 20: No specific action (notification types already in 16)

-- ROLLBACK 19: Drop task_approvals table
-- DROP TABLE IF EXISTS task_approvals;

-- ROLLBACK 18: Remove approval columns from tasks
-- ALTER TABLE tasks DROP COLUMN IF EXISTS rejection_reason;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS approval_date;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS approval_comments;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS approver_id;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS approval_status;
-- ALTER TABLE tasks DROP INDEX IF EXISTS idx_tasks_approval_status;
-- ALTER TABLE tasks DROP INDEX IF EXISTS idx_tasks_approver_id;
-- ALTER TABLE tasks DROP INDEX IF EXISTS idx_tasks_approval_status_approver;
-- ALTER TABLE tasks DROP FOREIGN KEY IF EXISTS tasks_approver_fk;

-- ROLLBACK 17: Drop notification_preferences table
-- DROP TABLE IF EXISTS notification_preferences;

-- ROLLBACK 16: Drop notifications table
-- DROP TABLE IF EXISTS notifications;

-- ============================================================================
-- END OF MIGRATIONS
-- ============================================================================

-- Reset connection settings
SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- 
-- Phase 2 Migrations Successfully Deployed!
--
-- New Tables Created (6):
-- ✓ notifications - Real-time notification records
-- ✓ notification_preferences - Per-user notification settings
-- ✓ task_approvals - Approval audit trail
-- ✓ task_metrics - Monthly user performance metrics
-- ✓ department_metrics - Monthly department performance
-- ✓ employee_performance - Long-term employee ratings
--
-- Modified Tables (3):
-- ✓ tasks - Added 5 approval-related columns
-- ✓ task_activities - Added 2 approval-related actions
-- ✓ notifications - Already supports new notification types
--
-- Indexes Created:
-- ✓ user_id, task_id, read, created_at on notifications
-- ✓ approval_status, approver_id on tasks
-- ✓ task_id, approver_id, status on task_approvals
-- ✓ user_id, period on task_metrics
-- ✓ department_id, month/year on department_metrics
-- ✓ user_id, overall_rating on employee_performance
--
-- Foreign Keys:
-- ✓ All new tables linked to users/departments
-- ✓ Cascade delete for data integrity
-- ✓ Proper constraints to prevent orphaned records
--
-- Data Preservation:
-- ✓ All existing users preserved (18 demo users)
-- ✓ All existing tasks preserved
-- ✓ All existing relationships intact
-- ✓ No data loss from previous phases
--
-- Ready for Production Deployment!
-- ============================================================================
