-- Studioinfinito Task Manager - Database Setup Script
-- Run this script to create the database and user

-- Create database
CREATE DATABASE IF NOT EXISTS task_manager 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE task_manager;

-- Create application user (optional - adjust password as needed)
-- CREATE USER IF NOT EXISTS 'task_manager'@'localhost' IDENTIFIED BY 'your_secure_password';
-- GRANT ALL PRIVILEGES ON task_manager.* TO 'task_manager'@'localhost';
-- FLUSH PRIVILEGES;

-- Note: Tables will be created automatically by Sequelize migrations
-- Run: npm run migrate (from backend directory)
