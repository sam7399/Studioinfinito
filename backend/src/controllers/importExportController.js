const ImportExportService = require('../services/importExportService');
const logger = require('../utils/logger');
const path = require('path');

class ImportExportController {
  static async importUsers(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded'
        });
      }

      const fileType = path.extname(req.file.originalname).toLowerCase() === '.csv' ? 'csv' : 'xlsx';
      const results = await ImportExportService.importUsers(req.file.path, fileType);
      
      logger.info(`User import completed: ${results.success.length} success, ${results.errors.length} errors`);
      
      res.json({
        success: true,
        data: results
      });
    } catch (error) {
      logger.error('Import users error:', error);
      next(error);
    }
  }

  static async downloadUserSample(req, res, next) {
    try {
      const ExcelJS = require('exceljs');
      const { Company, Department, Location } = require('../models');

      // ── Fetch live data for dropdowns ────────────────────────────────────────
      const [companies, departments, locations] = await Promise.all([
        Company.findAll({ attributes: ['name'], order: [['name', 'ASC']] }),
        Department.findAll({ attributes: ['name'], order: [['name', 'ASC']] }),
        Location.findAll({ attributes: ['name'], order: [['name', 'ASC']] })
      ]);

      const companyNames = companies.map(c => c.name);
      const deptNames    = departments.map(d => d.name);
      const locNames     = locations.map(l => l.name);
      const ROLES        = ['employee', 'manager', 'department_head', 'management', 'superadmin'];

      const wb = new ExcelJS.Workbook();

      // ── Reference Data sheet (hidden — feeds dropdown lists) ─────────────────
      const refSheet = wb.addWorksheet('Reference Data', { state: 'veryHidden' });
      refSheet.addRow(['Company', 'Department', 'Location', 'Role']);
      const refLen = Math.max(companyNames.length, deptNames.length, locNames.length, ROLES.length);
      for (let i = 0; i < refLen; i++) {
        refSheet.addRow([
          companyNames[i] ?? '',
          deptNames[i]    ?? '',
          locNames[i]     ?? '',
          ROLES[i]        ?? ''
        ]);
      }
      refSheet.columns = [{ width: 32 }, { width: 32 }, { width: 32 }, { width: 22 }];

      // ── Main template sheet ──────────────────────────────────────────────────
      const ws = wb.addWorksheet('Users Import Template');

      // Row 1 — human-readable descriptions
      const descRow = ws.addRow([
        'Full Name (required)',
        'Email Address (required — must be unique)',
        'Password (required — min 8 chars)',
        'Role — select from dropdown ▼',
        'Company — select from dropdown ▼',
        'Department — select from dropdown ▼',
        'Location — select from dropdown ▼',
        'Active Status (true/false) ▼',
        'Manager User ID (optional)'
      ]);
      descRow.eachCell(cell => {
        cell.font = { bold: true, color: { argb: 'FF1E40AF' } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFF6FF' } };
      });

      // Row 2 — machine-readable column keys (used by import parser)
      const headerRow = ws.addRow([
        'name', 'email', 'password', 'role',
        'company', 'department', 'location', 'is_active', 'manager_id'
      ]);
      headerRow.eachCell(cell => {
        cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E293B' } };
      });

      // Example rows
      const c0 = companyNames[0] || 'Gem Aromatics';
      const d0 = deptNames[0]    || 'Finance';
      const d1 = deptNames[1]    || deptNames[0] || 'Sales';
      const l0 = locNames[0]     || 'Head Office';
      ws.addRow(['Rahul Sharma', 'rahul@company.com', 'Password@123', 'employee',        c0, d0, l0, 'true', '']);
      ws.addRow(['Priya Mehta',  'priya@company.com', 'Password@123', 'manager',         c0, d1, l0, 'true', '']);
      ws.addRow(['Amit Kumar',   'amit@company.com',  'Password@123', 'department_head', c0, d0, l0, 'true', '']);

      ws.columns = [
        { width: 22 }, { width: 30 }, { width: 20 }, { width: 20 },
        { width: 24 }, { width: 24 }, { width: 24 }, { width: 18 }, { width: 22 }
      ];

      // Freeze rows 1–2 so headers stay visible while scrolling
      ws.views = [{ state: 'frozen', xSplit: 0, ySplit: 2 }];

      // ── Data validations — real dropdown arrows powered by Reference Data ─────
      const rlEnd = ROLES.length + 1;
      const coEnd = (companyNames.length || 1) + 1;
      const dpEnd = (deptNames.length    || 1) + 1;
      const lcEnd = (locNames.length     || 1) + 1;

      ws.dataValidations.add('D3:D10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$D$2:$D$${rlEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Role',
        error: 'Please select a valid role from the dropdown.'
      });
      ws.dataValidations.add('E3:E10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$A$2:$A$${coEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Company',
        error: 'Please select a company from the dropdown.'
      });
      ws.dataValidations.add('F3:F10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$B$2:$B$${dpEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Department',
        error: 'Please select a department from the dropdown.'
      });
      ws.dataValidations.add('G3:G10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$C$2:$C$${lcEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Location',
        error: 'Please select a location from the dropdown.'
      });
      ws.dataValidations.add('H3:H10000', {
        type: 'list', allowBlank: true,
        formulae: ['"true,false"'],
        showErrorMessage: true, errorTitle: 'Invalid Value',
        error: 'Please enter true or false.'
      });

      const buf = await wb.xlsx.writeBuffer();
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="sample_users_import.xlsx"');
      res.send(buf);
    } catch (error) {
      logger.error('Download user sample error:', error);
      next(error);
    }
  }

  static async downloadTaskSample(req, res, next) {
    try {
      const ExcelJS = require('exceljs');
      const { Company, Department, Location, User } = require('../models');

      // ── Fetch live data for dropdowns ────────────────────────────────────────
      const [companies, departments, locations, users] = await Promise.all([
        Company.findAll({ attributes: ['name'], order: [['name', 'ASC']] }),
        Department.findAll({ attributes: ['name'], order: [['name', 'ASC']] }),
        Location.findAll({ attributes: ['name'], order: [['name', 'ASC']] }),
        User.findAll({
          where: { is_active: true },
          attributes: ['name', 'email'],
          order: [['name', 'ASC']]
        })
      ]);

      const companyNames  = companies.map(c => c.name);
      const deptNames     = departments.map(d => d.name);
      const locNames      = locations.map(l => l.name);
      const userEmails    = users.map(u => u.email);
      const userNames     = users.map(u => u.name);
      const PRIORITIES    = ['low', 'normal', 'high', 'urgent'];
      const STATUSES      = ['open', 'in_progress'];

      const wb = new ExcelJS.Workbook();

      // ── Reference Data sheet (hidden) ────────────────────────────────────────
      const refSheet = wb.addWorksheet('Reference Data', { state: 'veryHidden' });
      refSheet.addRow(['User Email', 'User Name', 'Company', 'Department', 'Location', 'Priority', 'Status']);
      const refLen = Math.max(userEmails.length, companyNames.length, deptNames.length, locNames.length, PRIORITIES.length, STATUSES.length);
      for (let i = 0; i < refLen; i++) {
        refSheet.addRow([
          userEmails[i]   ?? '',
          userNames[i]    ?? '',
          companyNames[i] ?? '',
          deptNames[i]    ?? '',
          locNames[i]     ?? '',
          PRIORITIES[i]   ?? '',
          STATUSES[i]     ?? ''
        ]);
      }
      refSheet.columns = [
        { width: 30 }, { width: 24 }, { width: 28 },
        { width: 28 }, { width: 28 }, { width: 14 }, { width: 18 }
      ];

      // ── Main template sheet ──────────────────────────────────────────────────
      const ws = wb.addWorksheet('Tasks Import Template');

      // Row 1 — human-readable descriptions
      const descRow = ws.addRow([
        'Task Title (required)',
        'Description (optional)',
        'Assignee Email — select from dropdown ▼',
        'Company — select from dropdown ▼',
        'Department — select from dropdown ▼',
        'Location — select from dropdown ▼',
        'Priority — select from dropdown ▼',
        'Status — select from dropdown ▼',
        'Due Date (yyyy-mm-dd)',
        'Estimated Hours (optional)'
      ]);
      descRow.eachCell(cell => {
        cell.font = { bold: true, color: { argb: 'FF4C1D95' } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF5F3FF' } };
      });

      // Row 2 — machine-readable column keys
      const headerRow = ws.addRow([
        'title', 'description', 'assignedemail',
        'company', 'department', 'location',
        'priority', 'status', 'duedate', 'estimated_hours'
      ]);
      headerRow.eachCell(cell => {
        cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E293B' } };
      });

      // Example rows
      const c0  = companyNames[0]  || 'Gem Aromatics';
      const d0  = deptNames[0]     || 'Finance';
      const l0  = locNames[0]      || 'Head Office';
      const e0  = userEmails[0]    || 'user@company.com';
      const e1  = userEmails[1]    || userEmails[0] || 'user@company.com';
      const today = new Date().toISOString().split('T')[0];
      ws.addRow(['Prepare Q4 Report',     'Consolidate quarterly data', e0, c0, d0, l0, 'high',   'open', today, '8']);
      ws.addRow(['Factory Maintenance',    'Check all valves and pumps', e1, c0, d0, l0, 'urgent', 'open', today, '12']);
      ws.addRow(['Update Team Handbook',   'Review and revise policies', e0, c0, d0, l0, 'normal', 'open', today, '4']);

      ws.columns = [
        { width: 28 }, { width: 28 }, { width: 30 }, { width: 24 },
        { width: 24 }, { width: 24 }, { width: 14 }, { width: 18 },
        { width: 18 }, { width: 18 }
      ];

      ws.views = [{ state: 'frozen', xSplit: 0, ySplit: 2 }];

      // ── Data validations ─────────────────────────────────────────────────────
      const ueEnd = (userEmails.length  || 1) + 1;
      const coEnd = (companyNames.length || 1) + 1;
      const dpEnd = (deptNames.length    || 1) + 1;
      const lcEnd = (locNames.length     || 1) + 1;
      const prEnd = PRIORITIES.length + 1;
      const stEnd = STATUSES.length + 1;

      ws.dataValidations.add('C3:C10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$A$2:$A$${ueEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Assignee',
        error: 'Please select a valid user email from the dropdown.'
      });
      ws.dataValidations.add('D3:D10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$C$2:$C$${coEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Company',
        error: 'Please select a company from the dropdown.'
      });
      ws.dataValidations.add('E3:E10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$D$2:$D$${dpEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Department',
        error: 'Please select a department from the dropdown.'
      });
      ws.dataValidations.add('F3:F10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$E$2:$E$${lcEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Location',
        error: 'Please select a location from the dropdown.'
      });
      ws.dataValidations.add('G3:G10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$F$2:$F$${prEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Priority',
        error: 'Please select a priority from the dropdown.'
      });
      ws.dataValidations.add('H3:H10000', {
        type: 'list', allowBlank: true,
        formulae: [`'Reference Data'!$G$2:$G$${stEnd}`],
        showErrorMessage: true, errorTitle: 'Invalid Status',
        error: 'Please select a status from the dropdown.'
      });

      const buf = await wb.xlsx.writeBuffer();
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="sample_tasks_import.xlsx"');
      res.send(buf);
    } catch (error) {
      logger.error('Download task sample error:', error);
      next(error);
    }
  }

  static async exportUsers(req, res, next) {
    try {
      const users = await ImportExportService.exportUsers(req.query);

      const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
      const header = ['ID', 'Name', 'Email', 'Role', 'Is Active', 'Company', 'Department', 'Location', 'Last Login', 'Created At'].join(',');
      const rows = users.map(u => [
        u.id,
        esc(u.name),
        esc(u.email),
        u.role,
        u.is_active ? 'true' : 'false',
        esc(u.company?.name ?? ''),
        esc(u.department?.name ?? ''),
        esc(u.location?.name ?? ''),
        u.last_login_at ? new Date(u.last_login_at).toISOString().split('T')[0] : '',
        u.created_at ? new Date(u.created_at).toISOString().split('T')[0] : ''
      ].join(','));

      const csv = [header, ...rows].join('\n');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="users_${Date.now()}.csv"`);
      res.send(csv);
    } catch (error) {
      logger.error('Export users error:', error);
      next(error);
    }
  }

  static async importTasks(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded'
        });
      }

      const fileType = path.extname(req.file.originalname).toLowerCase() === '.csv' ? 'csv' : 'xlsx';
      const results = await ImportExportService.importTasks(req.file.path, fileType, req.user.id);
      
      logger.info(`Task import completed: ${results.success.length} success, ${results.errors.length} errors`);
      
      res.json({
        success: true,
        data: results
      });
    } catch (error) {
      logger.error('Import tasks error:', error);
      next(error);
    }
  }

  static async exportTasks(req, res, next) {
    try {
      const tasks = await ImportExportService.exportTasks(req.query);

      const esc = (v) => `"${String(v ?? '').replace(/"/g, '""').replace(/\n/g, ' ')}"`;
      const header = ['ID', 'Title', 'Description', 'Priority', 'Status', 'Assigned To', 'Assignee Email', 'Created By', 'Company', 'Department', 'Location', 'Due Date', 'Created At'].join(',');
      const rows = tasks.map(t => [
        t.id,
        esc(t.title),
        esc(t.description),
        t.priority,
        t.status,
        esc(t.assignedTo?.name ?? t.assignee?.name ?? ''),
        esc(t.assignedTo?.email ?? t.assignee?.email ?? ''),
        esc(t.createdBy?.name ?? t.creator?.name ?? ''),
        esc(t.company?.name ?? ''),
        esc(t.department?.name ?? ''),
        esc(t.location?.name ?? ''),
        t.due_date ? String(t.due_date).split('T')[0] : '',
        t.created_at ? new Date(t.created_at).toISOString().split('T')[0] : ''
      ].join(','));

      const csv = [header, ...rows].join('\n');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="tasks_${Date.now()}.csv"`);
      res.send(csv);
    } catch (error) {
      logger.error('Export tasks error:', error);
      next(error);
    }
  }
}

module.exports = ImportExportController;