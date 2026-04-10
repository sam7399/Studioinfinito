const fs = require('fs');
const path = require('path');
const csv = require('fast-csv');
const XLSX = require('xlsx');
const bcrypt = require('bcrypt');
const { User, Task, Company, Department, Location } = require('../models');
const logger = require('../utils/logger');

class ImportExportService {
  /**
   * Import users from CSV or Excel file
   */
  static async importUsers(filePath, fileType) {
    const results = {
      success: [],
      errors: []
    };

    try {
      const data = fileType === 'csv' 
        ? await this.readCSV(filePath)
        : await this.readExcel(filePath);

      for (let i = 0; i < data.length; i++) {
        const row = data[i];
        try {
          // Validate required fields
          if (!row.name || !row.email || !row.password) {
            results.errors.push({
              row: i + 1,
              data: row,
              error: 'Missing required fields: name, email, or password'
            });
            continue;
          }

          // Check if user already exists
          const existingUser = await User.findOne({ where: { email: row.email.toLowerCase() } });
          if (existingUser) {
            results.errors.push({
              row: i + 1,
              data: row,
              error: 'User with this email already exists'
            });
            continue;
          }

          // Hash password
          const password_hash = await bcrypt.hash(row.password, 10);

          // Resolve company name → ID (accept either company_id or company name)
          let company_id = row.company_id ? parseInt(row.company_id) : null;
          if (!company_id && row.company) {
            const co = await Company.findOne({ where: { name: row.company.trim() } });
            if (!co) {
              results.errors.push({ row: i + 1, data: row, error: `Company "${row.company}" not found` });
              continue;
            }
            company_id = co.id;
          }

          // Resolve department name → ID
          let department_id = row.department_id ? parseInt(row.department_id) : null;
          if (!department_id && row.department) {
            const dept = await Department.findOne({ where: { name: row.department.trim() } });
            if (!dept) {
              results.errors.push({ row: i + 1, data: row, error: `Department "${row.department}" not found` });
              continue;
            }
            department_id = dept.id;
          }

          // Resolve location name → ID
          let location_id = row.location_id ? parseInt(row.location_id) : null;
          if (!location_id && row.location) {
            const loc = await Location.findOne({ where: { name: row.location.trim() } });
            if (!loc) {
              results.errors.push({ row: i + 1, data: row, error: `Location "${row.location}" not found` });
              continue;
            }
            location_id = loc.id;
          }

          // Normalise is_active (Excel may send string "true"/"false")
          let is_active = true;
          if (row.is_active !== undefined && row.is_active !== '') {
            is_active = String(row.is_active).toLowerCase() !== 'false';
          }

          // Create user
          const userData = {
            name: row.name,
            email: row.email.toLowerCase(),
            password_hash,
            role: row.role || 'employee',
            is_active,
            company_id,
            department_id,
            location_id,
            manager_id: row.manager_id ? parseInt(row.manager_id) : null
          };

          const user = await User.create(userData);
          results.success.push({
            row: i + 1,
            user: {
              id: user.id,
              name: user.name,
              email: user.email
            }
          });
        } catch (error) {
          results.errors.push({
            row: i + 1,
            data: row,
            error: error.message
          });
        }
      }

      // Clean up uploaded file
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return results;
    } catch (error) {
      logger.error('Import users error:', error);
      throw error;
    }
  }

  /**
   * Export users to JSON format
   */
  static async exportUsers(filters = {}) {
    try {
      const where = {};

      if (filters.company_id) {
        where.company_id = filters.company_id;
      }
      if (filters.department_id) {
        where.department_id = filters.department_id;
      }
      if (filters.location_id) {
        where.location_id = filters.location_id;
      }
      if (filters.role) {
        where.role = filters.role;
      }
      if (filters.is_active !== undefined) {
        where.is_active = filters.is_active;
      }

      const users = await User.findAll({
        where,
        attributes: [
          'id', 'name', 'email', 'role', 'is_active',
          'company_id', 'department_id', 'location_id', 'manager_id',
          'last_login_at', 'created_at'
        ],
        include: [
          {
            model: Company,
            as: 'company',
            attributes: ['id', 'name']
          },
          {
            model: Department,
            as: 'department',
            attributes: ['id', 'name']
          },
          {
            model: Location,
            as: 'location',
            attributes: ['id', 'name']
          }
        ],
        order: [['created_at', 'DESC']]
      });

      return users;
    } catch (error) {
      logger.error('Export users error:', error);
      throw error;
    }
  }

  /**
   * Import tasks from CSV or Excel file
   */
  static async importTasks(filePath, fileType, createdByUserId) {
    const results = {
      success: [],
      errors: []
    };

    try {
      const data = fileType === 'csv' 
        ? await this.readCSV(filePath)
        : await this.readExcel(filePath);

      for (let i = 0; i < data.length; i++) {
        const row = data[i];
        try {
          // Validate required fields
          const assigneeRef = row.assignedemail || row.assigned_to_email || row.assigned_to_user_id;
          if (!row.title || !assigneeRef) {
            results.errors.push({
              row: i + 1,
              data: row,
              error: 'Missing required fields: title and assignedemail (or assigned_to_user_id)'
            });
            continue;
          }

          // Resolve assignee — accept email or numeric ID
          let assignedUser;
          if (row.assigned_to_user_id && !isNaN(row.assigned_to_user_id)) {
            assignedUser = await User.findByPk(parseInt(row.assigned_to_user_id));
          } else {
            const email = (row.assignedemail || row.assigned_to_email || '').trim().toLowerCase();
            if (email) assignedUser = await User.findOne({ where: { email } });
          }
          if (!assignedUser) {
            results.errors.push({
              row: i + 1,
              data: row,
              error: `Assignee "${assigneeRef}" not found`
            });
            continue;
          }

          // Resolve company name → ID
          let company_id = row.company_id ? parseInt(row.company_id) : null;
          if (!company_id && row.company) {
            const co = await Company.findOne({ where: { name: row.company.trim() } });
            if (!co) { results.errors.push({ row: i + 1, data: row, error: `Company "${row.company}" not found` }); continue; }
            company_id = co.id;
          }

          // Resolve department name → ID
          let department_id = row.department_id ? parseInt(row.department_id) : null;
          if (!department_id && row.department) {
            const dept = await Department.findOne({ where: { name: row.department.trim() } });
            if (!dept) { results.errors.push({ row: i + 1, data: row, error: `Department "${row.department}" not found` }); continue; }
            department_id = dept.id;
          }

          // Resolve location name → ID
          let location_id = row.location_id ? parseInt(row.location_id) : null;
          if (!location_id && row.location) {
            const loc = await Location.findOne({ where: { name: row.location.trim() } });
            if (!loc) { results.errors.push({ row: i + 1, data: row, error: `Location "${row.location}" not found` }); continue; }
            location_id = loc.id;
          }

          // Create task
          const taskData = {
            title: row.title,
            description: row.description || null,
            priority: row.priority || 'normal',
            status: row.status || 'open',
            due_date: row.due_date || row.duedate || null,
            estimated_hours: row.estimated_hours || null,
            progress_percent: row.progress_percent || 0,
            company_id,
            department_id,
            location_id,
            assigned_to_user_id: assignedUser.id,
            created_by_user_id: createdByUserId
          };

          const task = await Task.create(taskData);
          results.success.push({
            row: i + 1,
            task: {
              id: task.id,
              title: task.title,
              assigned_to: assignedUser.name
            }
          });
        } catch (error) {
          results.errors.push({
            row: i + 1,
            data: row,
            error: error.message
          });
        }
      }

      // Clean up uploaded file
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      return results;
    } catch (error) {
      logger.error('Import tasks error:', error);
      throw error;
    }
  }

  /**
   * Export tasks to JSON format
   */
  static async exportTasks(filters = {}) {
    try {
      const where = {};

      if (filters.company_id) {
        where.company_id = filters.company_id;
      }
      if (filters.department_id) {
        where.department_id = filters.department_id;
      }
      if (filters.location_id) {
        where.location_id = filters.location_id;
      }
      if (filters.assigned_to_user_id) {
        where.assigned_to_user_id = filters.assigned_to_user_id;
      }
      if (filters.status) {
        where.status = filters.status;
      }
      if (filters.priority) {
        where.priority = filters.priority;
      }

      const tasks = await Task.findAll({
        where,
        include: [
          {
            model: User,
            as: 'assignee',
            attributes: ['id', 'name', 'email']
          },
          {
            model: User,
            as: 'creator',
            attributes: ['id', 'name', 'email']
          },
          {
            model: Company,
            as: 'company',
            attributes: ['id', 'name']
          },
          {
            model: Department,
            as: 'department',
            attributes: ['id', 'name']
          },
          {
            model: Location,
            as: 'location',
            attributes: ['id', 'name']
          }
        ],
        order: [['created_at', 'DESC']]
      });

      return tasks;
    } catch (error) {
      logger.error('Export tasks error:', error);
      throw error;
    }
  }

  /**
   * Read CSV file
   */
  static readCSV(filePath) {
    return new Promise((resolve, reject) => {
      const results = [];
      fs.createReadStream(filePath)
        .pipe(csv.parse({ headers: true, trim: true }))
        .on('error', error => reject(error))
        .on('data', row => results.push(row))
        .on('end', () => resolve(results));
    });
  }

  /**
   * Read Excel file — auto-detects the header row so sample files with a
   * description row (row 1) + key row (row 2) import correctly.
   */
  static readExcel(filePath) {
    try {
      const workbook = XLSX.readFile(filePath);
      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];

      // Get raw rows as arrays
      const raw = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: '' });
      if (raw.length === 0) return [];

      // Known field names used in import templates
      const KNOWN = new Set([
        'name','email','password','title','assignedemail','assigned_to_email',
        'role','company','department','location','is_active','manager_id',
        'priority','status','duedate','due_date','estimated_hours','description'
      ]);

      // Find the first row (up to row 3) whose cells match known field names
      let headerIdx = 0;
      for (let i = 0; i < Math.min(raw.length, 3); i++) {
        const normalised = raw[i].map(v => String(v).toLowerCase().trim());
        if (normalised.filter(v => KNOWN.has(v)).length >= 2) {
          headerIdx = i;
          break;
        }
      }

      const headers = raw[headerIdx].map(v => String(v).trim());
      const data = [];
      for (let i = headerIdx + 1; i < raw.length; i++) {
        const row = raw[i];
        // Skip fully-empty rows
        if (row.every(v => v === '' || v === null || v === undefined)) continue;
        const obj = {};
        headers.forEach((h, ci) => {
          if (h) obj[h] = row[ci] !== undefined ? String(row[ci]).trim() : '';
        });
        data.push(obj);
      }
      return data;
    } catch (error) {
      logger.error('Read Excel error:', error);
      throw error;
    }
  }
}

module.exports = ImportExportService;