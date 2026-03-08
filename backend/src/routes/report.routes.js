const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const ReportController = require('../controllers/reportController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);
router.use(requireRole('superadmin', 'management', 'department_head', 'manager'));

const filterQuery = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(200).default(20),
  start_date: Joi.date().iso().allow(null, ''),
  end_date: Joi.date().iso().allow(null, ''),
  status: Joi.alternatives().try(
    Joi.string(),
    Joi.array().items(Joi.string())
  ).allow(null, ''),
  priority: Joi.alternatives().try(
    Joi.string(),
    Joi.array().items(Joi.string())
  ).allow(null, ''),
  user_id: Joi.number().integer().allow(null, ''),
  company_id: Joi.number().integer().allow(null, ''),
  department_id: Joi.number().integer().allow(null, ''),
  location_id: Joi.number().integer().allow(null, ''),
  search: Joi.string().max(200).allow(null, ''),
  sort_by: Joi.string().valid(
    'created_at', 'due_date', 'priority', 'status', 'title'
  ).default('created_at'),
  sort_order: Joi.string().valid('asc', 'desc').default('desc'),
  overdue: Joi.string().valid('true', 'false').allow(null, ''),
  group_by: Joi.string().valid('status', 'department', 'location', 'user', 'company', 'full').default('status')
});

// Detailed task worklist
router.get('/worklist', celebrate({ [Segments.QUERY]: filterQuery }), ReportController.getWorklist);

// Summary grouped by user/dept/company/location
router.get('/summary', celebrate({ [Segments.QUERY]: filterQuery }), ReportController.getSummary);

// Export as CSV download
router.get('/export', celebrate({ [Segments.QUERY]: filterQuery }), ReportController.exportCSV);

// Export as multi-sheet Excel download
router.get('/export-excel', celebrate({ [Segments.QUERY]: filterQuery }), ReportController.exportExcel);

// HR appraisal performance matrix
router.get('/hr-matrix', ReportController.getHRMatrix);

// Send report via email
router.post(
  '/email',
  celebrate({
    [Segments.BODY]: Joi.object({
      recipient_email: Joi.string().email().required(),
      subject: Joi.string().max(200).allow(null, ''),
      filters: Joi.object().default({})
    })
  }),
  ReportController.sendReportEmail
);

module.exports = router;
