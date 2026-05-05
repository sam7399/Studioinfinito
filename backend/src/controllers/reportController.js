const { Task, User, Company, Department, Location } = require('../models');
const { Op } = require('sequelize');
const Mailer = require('../mail/mailer');
const logger = require('../utils/logger');

// ── Helpers ──────────────────────────────────────────────────────────────────

function buildWhereClause(query, requestingUser) {
  const {
    start_date, end_date, status, priority,
    user_id, company_id, department_id, location_id, search
  } = query;

  const where = {};

  // Company scope for non-superadmin
  if (requestingUser.role !== 'superadmin') {
    where.company_id = requestingUser.company_id;
  } else if (company_id) {
    where.company_id = company_id;
  }

  if (status) {
    where.status = Array.isArray(status) ? { [Op.in]: status } : status;
  }
  if (priority) {
    where.priority = Array.isArray(priority) ? { [Op.in]: priority } : priority;
  }
  if (user_id) where.assigned_to_user_id = user_id;
  if (department_id) where.department_id = department_id;
  if (location_id) where.location_id = location_id;

  if (start_date || end_date) {
    where.created_at = {};
    if (start_date) where.created_at[Op.gte] = new Date(start_date);
    if (end_date) {
      const end = new Date(end_date);
      end.setHours(23, 59, 59, 999);
      where.created_at[Op.lte] = end;
    }
  }

  if (search) {
    where[Op.or] = [
      { title: { [Op.like]: `%${search}%` } },
      { description: { [Op.like]: `%${search}%` } }
    ];
  }

  // Overdue: due_date < today AND not finalized
  if (query.overdue === 'true') {
    where.due_date = { [Op.lt]: new Date() };
    where.status = { [Op.notIn]: ['finalized'] };
  }

  return where;
}

const { TaskAssignment } = require('../models');

const TASK_INCLUDES = [
  { model: Company, as: 'company', attributes: ['id', 'name'] },
  { model: Department, as: 'department', attributes: ['id', 'name'] },
  { model: Location, as: 'location', attributes: ['id', 'name'] },
  {
    model: User, as: 'assignee',
    attributes: ['id', 'name', 'email', 'phone', 'designation'],
    include: [{ model: User, as: 'manager', attributes: ['id', 'name'] }]
  },
  { model: User, as: 'creator', attributes: ['id', 'name', 'email', 'phone'] },
  {
    model: User, as: 'collaborators',
    attributes: ['id', 'name', 'email'],
    through: { attributes: [] }
  }
];

// ── Controllers ───────────────────────────────────────────────────────────────

class ReportController {

  // GET /reports/worklist
  static async getWorklist(req, res, next) {
    try {
      const {
        page = 1, limit = 20,
        sort_by = 'created_at', sort_order = 'desc'
      } = req.query;

      const where = buildWhereClause(req.query, req.user);
      const offset = (page - 1) * limit;

      const allowedSortCols = ['created_at', 'due_date', 'priority', 'status', 'title'];
      const sortCol = allowedSortCols.includes(sort_by) ? sort_by : 'created_at';
      const sortDir = sort_order === 'asc' ? 'ASC' : 'DESC';

      const { count, rows } = await Task.findAndCountAll({
        where,
        include: TASK_INCLUDES,
        order: [[sortCol, sortDir]],
        limit: parseInt(limit),
        offset: parseInt(offset),
        distinct: true
      });

      res.json({
        success: true,
        data: {
          tasks: rows,
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
            total: count,
            pages: Math.ceil(count / limit)
          }
        }
      });
    } catch (error) {
      logger.error('Report worklist error:', error);
      next(error);
    }
  }

  // GET /reports/summary
  static async getSummary(req, res, next) {
    try {
      const where = buildWhereClause(req.query, req.user);
      const sequelize = Task.sequelize;

      const statusCases = (field) => `
        SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) as open_count,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
        SUM(CASE WHEN status = 'complete_pending_review' THEN 1 ELSE 0 END) as pending_review_count,
        SUM(CASE WHEN status = 'finalized' THEN 1 ELSE 0 END) as finalized_count,
        SUM(CASE WHEN status = 'reopened' THEN 1 ELSE 0 END) as reopened_count,
        SUM(CASE WHEN due_date IS NOT NULL AND due_date < CURDATE() AND status NOT IN ('finalized','cancelled') THEN 1 ELSE 0 END) as overdue_count,
        COUNT(*) as total_count
      `;

      // By User
      const byUser = await Task.findAll({
        where,
        attributes: [
          'assigned_to_user_id',
          [sequelize.literal(`SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END)`), 'open'],
          [sequelize.literal(`SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END)`), 'in_progress'],
          [sequelize.literal(`SUM(CASE WHEN status = 'complete_pending_review' THEN 1 ELSE 0 END)`), 'pending_review'],
          [sequelize.literal(`SUM(CASE WHEN status = 'finalized' THEN 1 ELSE 0 END)`), 'finalized'],
          [sequelize.literal(`SUM(CASE WHEN status = 'reopened' THEN 1 ELSE 0 END)`), 'reopened'],
          [sequelize.literal(`SUM(CASE WHEN due_date IS NOT NULL AND due_date < CURDATE() AND status NOT IN ('finalized') THEN 1 ELSE 0 END)`), 'overdue'],
          [sequelize.fn('COUNT', sequelize.col('Task.id')), 'total']
        ],
        include: [{
          model: User, as: 'assignee',
          attributes: ['id', 'name', 'email', 'designation'],
          include: [{ model: User, as: 'manager', attributes: ['id', 'name'] }]
        }],
        group: ['assigned_to_user_id', 'assignee.id', 'assignee->manager.id'],
        order: [[sequelize.fn('COUNT', sequelize.col('Task.id')), 'DESC']]
      });

      // By Department
      const byDepartment = await Task.findAll({
        where,
        attributes: [
          'department_id',
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'open' THEN 1 ELSE 0 END)`), 'open'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'in_progress' THEN 1 ELSE 0 END)`), 'in_progress'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'complete_pending_review' THEN 1 ELSE 0 END)`), 'pending_review'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'finalized' THEN 1 ELSE 0 END)`), 'finalized'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`due_date\` IS NOT NULL AND \`Task\`.\`due_date\` < CURDATE() AND \`Task\`.\`status\` NOT IN ('finalized') THEN 1 ELSE 0 END)`), 'overdue'],
          [sequelize.fn('COUNT', sequelize.col('Task.id')), 'total']
        ],
        include: [{
          model: Department, as: 'department',
          attributes: ['id', 'name'],
          include: [{ model: Company, as: 'company', attributes: ['id', 'name'] }]
        }],
        group: ['department_id', 'department.id', 'department->company.id'],
        order: [[sequelize.fn('COUNT', sequelize.col('Task.id')), 'DESC']]
      });

      // By Company
      const byCompany = await Task.findAll({
        where,
        attributes: [
          'company_id',
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'open' THEN 1 ELSE 0 END)`), 'open'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'in_progress' THEN 1 ELSE 0 END)`), 'in_progress'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'complete_pending_review' THEN 1 ELSE 0 END)`), 'pending_review'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'finalized' THEN 1 ELSE 0 END)`), 'finalized'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`due_date\` IS NOT NULL AND \`Task\`.\`due_date\` < CURDATE() AND \`Task\`.\`status\` NOT IN ('finalized') THEN 1 ELSE 0 END)`), 'overdue'],
          [sequelize.fn('COUNT', sequelize.col('Task.id')), 'total']
        ],
        include: [{ model: Company, as: 'company', attributes: ['id', 'name'] }],
        group: ['company_id', 'company.id'],
        order: [[sequelize.fn('COUNT', sequelize.col('Task.id')), 'DESC']]
      });

      // By Location
      const byLocation = await Task.findAll({
        where,
        attributes: [
          'location_id',
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'open' THEN 1 ELSE 0 END)`), 'open'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'in_progress' THEN 1 ELSE 0 END)`), 'in_progress'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'complete_pending_review' THEN 1 ELSE 0 END)`), 'pending_review'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`status\` = 'finalized' THEN 1 ELSE 0 END)`), 'finalized'],
          [sequelize.literal(`SUM(CASE WHEN \`Task\`.\`due_date\` IS NOT NULL AND \`Task\`.\`due_date\` < CURDATE() AND \`Task\`.\`status\` NOT IN ('finalized') THEN 1 ELSE 0 END)`), 'overdue'],
          [sequelize.fn('COUNT', sequelize.col('Task.id')), 'total']
        ],
        include: [{ model: Location, as: 'location', attributes: ['id', 'name'] }],
        group: ['location_id', 'location.id'],
        order: [[sequelize.fn('COUNT', sequelize.col('Task.id')), 'DESC']]
      });

      // Sequelize returns SUM/COUNT as strings in MySQL — parse to int
      const n = (v) => parseInt(v) || 0;
      const parseRow = (r) => ({
        ...r.toJSON(),
        open: n(r.dataValues.open),
        in_progress: n(r.dataValues.in_progress),
        pending_review: n(r.dataValues.pending_review),
        finalized: n(r.dataValues.finalized),
        reopened: n(r.dataValues.reopened ?? 0),
        overdue: n(r.dataValues.overdue),
        total: n(r.dataValues.total)
      });

      res.json({
        success: true,
        data: {
          byUser: byUser.map(parseRow),
          byDepartment: byDepartment.map(parseRow),
          byCompany: byCompany.map(parseRow),
          byLocation: byLocation.map(parseRow)
        }
      });
    } catch (error) {
      logger.error('Report summary error:', error);
      next(error);
    }
  }

  // POST /reports/email  { recipient_email, subject?, filters }
  static async sendReportEmail(req, res, next) {
    try {
      const { recipient_email, subject, filters = {} } = req.body;

      const where = buildWhereClause(filters, req.user);
      const tasks = await Task.findAll({
        where,
        include: TASK_INCLUDES,
        order: [['created_at', 'DESC']],
        limit: 1000
      });

      // Build CSV
      const csvHeader = [
        'ID', 'Company', 'Task Title', 'Description', 'Priority', 'Status',
        'Assigned To', 'Assignee Email', 'Manager',
        'Department', 'Location', 'Raised By', 'Raised By Contact',
        'Created Date', 'Due Date', 'Completed At', 'Collaborators'
      ].join(',');

      const csvRows = tasks.map(t => [
        t.id,
        `"${t.company?.name || ''}"`,
        `"${(t.title || '').replace(/"/g, '""')}"`,
        `"${(t.description || '').replace(/"/g, '""').replace(/\n/g, ' ')}"`,
        t.priority,
        t.status,
        `"${t.assignee?.name || ''}"`,
        t.assignee?.email || '',
        `"${t.assignee?.manager?.name || ''}"`,
        `"${t.department?.name || ''}"`,
        `"${t.location?.name || ''}"`,
        `"${t.creator?.name || ''}"`,
        t.creator?.phone || '',
        t.created_at ? new Date(t.created_at).toLocaleDateString() : '',
        t.due_date || '',
        t.completed_at ? new Date(t.completed_at).toLocaleDateString() : '',
        `"${(t.collaborators || []).map(c => c.name).join('; ')}"`
      ].join(','));

      const csvContent = [csvHeader, ...csvRows].join('\n');

      const reportTitle = subject || `Task Report - ${new Date().toLocaleDateString()}`;
      const html = `
        <h2>${reportTitle}</h2>
        <p>Please find the task report attached.</p>
        <p>Total tasks: <strong>${tasks.length}</strong></p>
        <p>Generated on: ${new Date().toLocaleString()}</p>
        <hr/>
        <p style="color:#666;font-size:12px">This report was generated automatically.</p>
      `;

      await Mailer.sendMail(
        recipient_email,
        reportTitle,
        html,
        [{
          filename: `task_report_${Date.now()}.csv`,
          content: csvContent,
          contentType: 'text/csv'
        }]
      );

      res.json({ success: true, message: `Report sent to ${recipient_email}` });
    } catch (error) {
      logger.error('Send report email error:', error);
      next(error);
    }
  }

  // GET /reports/export-excel  — returns multi-sheet XLSX (group_by: status|department|location|user|company|full)
  static async exportExcel(req, res, next) {
    try {
      const ExcelJS = require('exceljs');
      const baseWhere = buildWhereClause(req.query, req.user);
      const groupBy = req.query.group_by || 'status';
      const now = new Date();

      const TASK_HEADERS = [
        'ID', 'Company', 'Task Title', 'Description', 'Priority', 'Status',
        'Assigned To', 'Assignee Email', 'Manager', 'Department', 'Location',
        'Raised By', 'Raised By Contact', 'Created Date', 'Due Date', 'Completed At',
        'Collaborators'
      ];

      const SUMMARY_HEADERS = [
        'Name', 'Total', 'Open', 'In Progress', 'Pending Review',
        'Finalized', 'Reopened', 'Overdue'
      ];

      const taskToRow = (t) => [
        t.id,
        t.company?.name || '',
        t.title || '',
        (t.description || '').replace(/\n/g, ' '),
        t.priority || '',
        t.status || '',
        t.assignee?.name || '',
        t.assignee?.email || '',
        t.assignee?.manager?.name || '',
        t.department?.name || '',
        t.location?.name || '',
        t.creator?.name || '',
        t.creator?.phone || '',
        t.created_at ? new Date(t.created_at).toISOString().split('T')[0] : '',
        t.due_date ? String(t.due_date).split('T')[0] : '',
        t.completed_at ? new Date(t.completed_at).toISOString().split('T')[0] : '',
        (t.collaborators || []).map(c => c.name).join('; ')
      ];

      const summarizeGroup = (label, tasks) => [
        label,
        tasks.length,
        tasks.filter(t => t.status === 'open').length,
        tasks.filter(t => t.status === 'in_progress').length,
        tasks.filter(t => t.status === 'complete_pending_review').length,
        tasks.filter(t => t.status === 'finalized').length,
        tasks.filter(t => t.status === 'reopened').length,
        tasks.filter(t => t.due_date && new Date(t.due_date) < now && t.status !== 'finalized').length
      ];

      const makeSheet = (headers, rows) => {
        const worksheet = workbook.addWorksheet('temp');
        worksheet.addRow(headers);
        rows.forEach(row => worksheet.addRow(row));
        // Set column widths
        headers.forEach((h, ci) => {
          const max = [h, ...rows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          worksheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        worksheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];
        return worksheet;
      };

      const fetchTasks = (where) => Task.findAll({
        where,
        include: TASK_INCLUDES,
        order: [['created_at', 'DESC']],
        limit: 5000
      });

      // Safe sheet name: max 31 chars, no special chars, deduplicated
      const usedNames = new Set();
      const safeName = (name) => {
        let s = String(name || 'Sheet').replace(/[:\\/\[\]*?]/g, '').trim().substring(0, 31);
        if (!s) s = 'Sheet';
        let orig = s, n = 2;
        while (usedNames.has(s)) s = orig.substring(0, 28) + ' ' + (n++);
        usedNames.add(s);
        return s;
      };

      const addTaskSheet = (wb, tasks, name) => {
        const worksheet = wb.addWorksheet(safeName(name));
        worksheet.addRow(TASK_HEADERS);
        tasks.map(taskToRow).forEach(row => worksheet.addRow(row));
        // Set column widths
        TASK_HEADERS.forEach((h, ci) => {
          const max = [h, ...tasks.map(t => String(taskToRow(t)[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          worksheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        worksheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];
      };

      const wb = new ExcelJS.Workbook();

      // ── GROUP BY STATUS ─────────────────────────────────────────────────────
      if (groupBy === 'status') {
        const defs = [
          { name: 'All Tasks',      where: { ...baseWhere } },
          { name: 'Open Tasks',     where: { ...baseWhere, status: 'open' } },
          { name: 'In Progress',    where: { ...baseWhere, status: 'in_progress' } },
          { name: 'Pending Review', where: { ...baseWhere, status: 'complete_pending_review' } },
          { name: 'Finalized',      where: { ...baseWhere, status: 'finalized' } },
          { name: 'Reopened',       where: { ...baseWhere, status: 'reopened' } },
          { name: 'Overdue',        where: { ...baseWhere, due_date: { [Op.lt]: now }, status: { [Op.notIn]: ['finalized'] } } }
        ];
        for (const def of defs) addTaskSheet(wb, await fetchTasks(def.where), def.name);

      // ── GROUP BY DEPARTMENT ─────────────────────────────────────────────────
      } else if (groupBy === 'department') {
        const allTasks = await fetchTasks(baseWhere);
        addTaskSheet(wb, allTasks, 'All Tasks');
        const map = new Map();
        allTasks.forEach(t => {
          const key = t.department_id ?? 'none';
          const name = t.department?.name || 'No Department';
          if (!map.has(key)) map.set(key, { name, tasks: [] });
          map.get(key).tasks.push(t);
        });
        for (const { name, tasks } of map.values()) addTaskSheet(wb, tasks, name);

      // ── GROUP BY LOCATION ───────────────────────────────────────────────────
      } else if (groupBy === 'location') {
        const allTasks = await fetchTasks(baseWhere);
        addTaskSheet(wb, allTasks, 'All Tasks');
        const map = new Map();
        allTasks.forEach(t => {
          const key = t.location_id ?? 'none';
          const name = t.location?.name || 'No Location';
          if (!map.has(key)) map.set(key, { name, tasks: [] });
          map.get(key).tasks.push(t);
        });
        for (const { name, tasks } of map.values()) addTaskSheet(wb, tasks, name);

      // ── GROUP BY USER ───────────────────────────────────────────────────────
      } else if (groupBy === 'user') {
        const allTasks = await fetchTasks(baseWhere);
        addTaskSheet(wb, allTasks, 'All Tasks');
        const map = new Map();
        allTasks.forEach(t => {
          const key = t.assigned_to_user_id ?? 'none';
          const name = t.assignee?.name || 'Unassigned';
          if (!map.has(key)) map.set(key, { name, tasks: [] });
          map.get(key).tasks.push(t);
        });
        for (const { name, tasks } of map.values()) addTaskSheet(wb, tasks, name);

      // ── GROUP BY COMPANY ────────────────────────────────────────────────────
      } else if (groupBy === 'company') {
        const allTasks = await fetchTasks(baseWhere);
        addTaskSheet(wb, allTasks, 'All Tasks');
        const map = new Map();
        allTasks.forEach(t => {
          const key = t.company_id ?? 'none';
          const name = t.company?.name || 'No Company';
          if (!map.has(key)) map.set(key, { name, tasks: [] });
          map.get(key).tasks.push(t);
        });
        for (const { name, tasks } of map.values()) addTaskSheet(wb, tasks, name);

      // ── FULL REPORT ─────────────────────────────────────────────────────────
      } else if (groupBy === 'full') {
        const allTasks = await fetchTasks(baseWhere);
        addTaskSheet(wb, allTasks, 'All Tasks');

        // Status summary
        const statusRows = [
          summarizeGroup('Open',           allTasks.filter(t => t.status === 'open')),
          summarizeGroup('In Progress',    allTasks.filter(t => t.status === 'in_progress')),
          summarizeGroup('Pending Review', allTasks.filter(t => t.status === 'complete_pending_review')),
          summarizeGroup('Finalized',      allTasks.filter(t => t.status === 'finalized')),
          summarizeGroup('Reopened',       allTasks.filter(t => t.status === 'reopened')),
          summarizeGroup('Overdue',        allTasks.filter(t => t.due_date && new Date(t.due_date) < now && t.status !== 'finalized'))
        ];
        const statusSheet = wb.addWorksheet(safeName('Status Summary'));
        statusSheet.addRow(SUMMARY_HEADERS);
        statusRows.forEach(row => statusSheet.addRow(row));
        SUMMARY_HEADERS.forEach((h, ci) => {
          const max = [h, ...statusRows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          statusSheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        statusSheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

        // Department summary
        const deptMap = new Map();
        allTasks.forEach(t => {
          const key = t.department_id ?? 'none';
          const name = t.department?.name || 'No Department';
          if (!deptMap.has(key)) deptMap.set(key, { name, tasks: [] });
          deptMap.get(key).tasks.push(t);
        });
        const deptRows = [...deptMap.values()].map(({ name, tasks }) => summarizeGroup(name, tasks));
        const deptSheet = wb.addWorksheet(safeName('Dept Summary'));
        deptSheet.addRow(SUMMARY_HEADERS);
        deptRows.forEach(row => deptSheet.addRow(row));
        SUMMARY_HEADERS.forEach((h, ci) => {
          const max = [h, ...deptRows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          deptSheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        deptSheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

        // Location summary
        const locMap = new Map();
        allTasks.forEach(t => {
          const key = t.location_id ?? 'none';
          const name = t.location?.name || 'No Location';
          if (!locMap.has(key)) locMap.set(key, { name, tasks: [] });
          locMap.get(key).tasks.push(t);
        });
        const locRows = [...locMap.values()].map(({ name, tasks }) => summarizeGroup(name, tasks));
        const locSheet = wb.addWorksheet(safeName('Location Summary'));
        locSheet.addRow(SUMMARY_HEADERS);
        locRows.forEach(row => locSheet.addRow(row));
        SUMMARY_HEADERS.forEach((h, ci) => {
          const max = [h, ...locRows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          locSheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        locSheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

        // User summary
        const userMap = new Map();
        allTasks.forEach(t => {
          const key = t.assigned_to_user_id ?? 'none';
          const name = t.assignee?.name || 'Unassigned';
          if (!userMap.has(key)) userMap.set(key, { name, tasks: [] });
          userMap.get(key).tasks.push(t);
        });
        const userRows = [...userMap.values()].map(({ name, tasks }) => summarizeGroup(name, tasks));
        const userSheet = wb.addWorksheet(safeName('User Summary'));
        userSheet.addRow(SUMMARY_HEADERS);
        userRows.forEach(row => userSheet.addRow(row));
        SUMMARY_HEADERS.forEach((h, ci) => {
          const max = [h, ...userRows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          userSheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        userSheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

        // Company summary
        const coMap = new Map();
        allTasks.forEach(t => {
          const key = t.company_id ?? 'none';
          const name = t.company?.name || 'No Company';
          if (!coMap.has(key)) coMap.set(key, { name, tasks: [] });
          coMap.get(key).tasks.push(t);
        });
        const coRows = [...coMap.values()].map(({ name, tasks }) => summarizeGroup(name, tasks));
        const coSheet = wb.addWorksheet(safeName('Company Summary'));
        coSheet.addRow(SUMMARY_HEADERS);
        coRows.forEach(row => coSheet.addRow(row));
        SUMMARY_HEADERS.forEach((h, ci) => {
          const max = [h, ...coRows.map(r => String(r[ci] ?? ''))].reduce((m, cell) => Math.max(m, cell.length), 0);
          coSheet.getColumn(ci + 1).width = Math.min(max + 2, 60);
        });
        coSheet.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];
      }

      const buf = await wb.xlsx.writeBuffer();
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="task_report_${Date.now()}.xlsx"`);
      res.send(buf);
    } catch (error) {
      logger.error('Export Excel error:', error);
      next(error);
    }
  }

  // GET /reports/export  — returns CSV directly
  static async exportCSV(req, res, next) {
    try {
      const where = buildWhereClause(req.query, req.user);
      const tasks = await Task.findAll({
        where,
        include: TASK_INCLUDES,
        order: [['created_at', 'DESC']],
        limit: 5000
      });

      const csvHeader = [
        'ID', 'Company', 'Task Title', 'Description', 'Priority', 'Status',
        'Assigned To', 'Assignee Email', 'Manager', 'Department', 'Location',
        'Raised By', 'Raised By Contact', 'Created Date', 'Due Date', 'Completed At',
        'Collaborators'
      ].join(',');

      const csvRows = tasks.map(t => [
        t.id,
        `"${t.company?.name || ''}"`,
        `"${(t.title || '').replace(/"/g, '""')}"`,
        `"${(t.description || '').replace(/"/g, '""').replace(/\n/g, ' ')}"`,
        t.priority,
        t.status,
        `"${t.assignee?.name || ''}"`,
        t.assignee?.email || '',
        `"${t.assignee?.manager?.name || ''}"`,
        `"${t.department?.name || ''}"`,
        `"${t.location?.name || ''}"`,
        `"${t.creator?.name || ''}"`,
        t.creator?.phone || '',
        t.created_at ? new Date(t.created_at).toISOString().split('T')[0] : '',
        t.due_date || '',
        t.completed_at ? new Date(t.completed_at).toISOString().split('T')[0] : '',
        `"${(t.collaborators || []).map(c => c.name).join('; ')}"`
      ].join(','));

      const csv = [csvHeader, ...csvRows].join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="task_report_${Date.now()}.csv"`);
      res.send(csv);
    } catch (error) {
      logger.error('Export CSV error:', error);
      next(error);
    }
  }

  /**
   * GET /reports/hr-matrix
   * Returns per-employee performance metrics for the HR appraisal matrix.
   * Uses 4 bulk GROUP BY queries instead of N×6 per-user queries.
   */
  static async getHRMatrix(req, res, next) {
    try {
      const { department_id, location_id } = req.query;
      const requestingUser = req.user;
      const { sequelize: seq } = require('../models');
      const { TaskReview } = require('../models');
      const now = new Date();

      // 1. Fetch target users (1 query)
      const userWhere = { is_active: true };
      if (requestingUser.role !== 'superadmin') userWhere.company_id = requestingUser.company_id;
      if (department_id) userWhere.department_id = department_id;
      if (location_id) userWhere.location_id = location_id;

      const users = await User.findAll({
        where: userWhere,
        attributes: ['id', 'name', 'email', 'designation', 'emp_code'],
        include: [
          { model: Department, as: 'department', attributes: ['id', 'name'] },
          { model: Location, as: 'location', attributes: ['id', 'name'] }
        ],
        order: [['name', 'ASC']]
      });

      if (users.length === 0) return res.json({ success: true, data: [] });

      const userIds = users.map(u => u.id);

      // 2. Task status counts grouped by user (1 query)
      const taskCounts = await Task.findAll({
        where: { assigned_to_user_id: { [Op.in]: userIds } },
        attributes: [
          'assigned_to_user_id',
          'status',
          [seq.fn('COUNT', seq.col('id')), 'cnt']
        ],
        group: ['assigned_to_user_id', 'status'],
        raw: true
      });

      // 3. Overdue counts grouped by user (1 query)
      const overdueCounts = await Task.findAll({
        where: {
          assigned_to_user_id: { [Op.in]: userIds },
          status: { [Op.notIn]: ['finalized', 'cancelled'] },
          due_date: { [Op.lt]: now }
        },
        attributes: [
          'assigned_to_user_id',
          [seq.fn('COUNT', seq.col('id')), 'cnt']
        ],
        group: ['assigned_to_user_id'],
        raw: true
      });

      // 4. Review averages grouped by assignee (1 query via JOIN)
      const reviewStats = await TaskReview.findAll({
        include: [{
          model: Task, as: 'task',
          where: { assigned_to_user_id: { [Op.in]: userIds } },
          attributes: ['assigned_to_user_id']
        }],
        attributes: [
          [seq.fn('COUNT', seq.col('TaskReview.id')), 'review_count'],
          [seq.fn('AVG', seq.col('TaskReview.rating')), 'avg_rating'],
          [seq.fn('AVG', seq.col('TaskReview.quality_score')), 'avg_quality'],
          [seq.fn('AVG', seq.col('TaskReview.timeliness_score')), 'avg_timeliness']
        ],
        group: ['task.assigned_to_user_id'],
        raw: true
      });

      // 5. On-time completion (finalized tasks with both dates) — 1 query
      const finalizedRows = await Task.findAll({
        where: {
          assigned_to_user_id: { [Op.in]: userIds },
          status: 'finalized',
          completed_at: { [Op.ne]: null },
          due_date: { [Op.ne]: null }
        },
        attributes: ['assigned_to_user_id', 'due_date', 'completed_at'],
        raw: true
      });

      // Build lookup maps
      const taskMap = {};   // uid → { total, open, in_progress, finalized }
      for (const row of taskCounts) {
        const uid = row.assigned_to_user_id;
        if (!taskMap[uid]) taskMap[uid] = { total: 0, open: 0, in_progress: 0, finalized: 0 };
        taskMap[uid].total += parseInt(row.cnt);
        if (row.status === 'open') taskMap[uid].open = parseInt(row.cnt);
        if (row.status === 'in_progress') taskMap[uid].in_progress = parseInt(row.cnt);
        if (row.status === 'finalized') taskMap[uid].finalized = parseInt(row.cnt);
      }

      const overdueMap = {};
      for (const row of overdueCounts) overdueMap[row.assigned_to_user_id] = parseInt(row.cnt);

      const reviewMap = {};
      for (const row of reviewStats) {
        const uid = row['task.assigned_to_user_id'];
        if (uid) reviewMap[uid] = row;
      }

      const onTimeMap = {};  // uid → { done, onTime }
      for (const row of finalizedRows) {
        const uid = row.assigned_to_user_id;
        if (!onTimeMap[uid]) onTimeMap[uid] = { done: 0, onTime: 0 };
        onTimeMap[uid].done++;
        if (new Date(row.completed_at) <= new Date(row.due_date)) onTimeMap[uid].onTime++;
      }

      // Assemble matrix
      const matrix = users.map(u => {
        const uid = u.id;
        const tc = taskMap[uid] || { total: 0, open: 0, in_progress: 0, finalized: 0 };
        const rv = reviewMap[uid];
        const ot = onTimeMap[uid];

        return {
          user: {
            id: u.id, name: u.name, email: u.email,
            designation: u.designation, emp_code: u.emp_code,
            department: u.department ? { id: u.department.id, name: u.department.name } : null,
            location: u.location ? { id: u.location.id, name: u.location.name } : null
          },
          total_tasks: tc.total,
          open_tasks: tc.open,
          in_progress_tasks: tc.in_progress,
          completed_tasks: tc.finalized,
          overdue_tasks: overdueMap[uid] || 0,
          review_count: rv ? parseInt(rv.review_count) : 0,
          avg_rating: rv?.avg_rating ? Math.round(parseFloat(rv.avg_rating) * 10) / 10 : null,
          avg_quality_score: rv?.avg_quality ? Math.round(parseFloat(rv.avg_quality) * 10) / 10 : null,
          avg_timeliness_score: rv?.avg_timeliness ? Math.round(parseFloat(rv.avg_timeliness) * 10) / 10 : null,
          on_time_rate: ot ? Math.round((ot.onTime / ot.done) * 1000) / 10 : null
        };
      });

      res.json({ success: true, data: matrix });
    } catch (error) {
      logger.error('HR matrix error:', error);
      next(error);
    }
  }
}

module.exports = ReportController;
