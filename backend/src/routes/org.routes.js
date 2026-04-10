const express = require('express');
const { celebrate, Joi, Segments } = require('celebrate');
const OrgController = require('../controllers/orgController');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

// ── Companies (superadmin only) ──────────────────────────────────
router.get('/companies', OrgController.listCompanies);

router.post('/companies',
  requireRole('superadmin'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2).required(), domain: Joi.string().allow('', null) }) }),
  OrgController.createCompany
);

router.put('/companies/:id',
  requireRole('superadmin'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2), domain: Joi.string().allow('', null), is_active: Joi.boolean() }) }),
  OrgController.updateCompany
);

router.delete('/companies/:id', requireRole('superadmin'), OrgController.deleteCompany);

// ── Departments (superadmin + management) ────────────────────────
router.get('/departments', OrgController.listDepartments);

router.post('/departments',
  requireRole('superadmin', 'management'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2).required(), company_id: Joi.number().integer().required() }) }),
  OrgController.createDepartment
);

router.put('/departments/:id',
  requireRole('superadmin', 'management'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2), is_active: Joi.boolean() }) }),
  OrgController.updateDepartment
);

router.delete('/departments/:id', requireRole('superadmin', 'management'), OrgController.deleteDepartment);

// ── Locations (superadmin + management) ──────────────────────────
router.get('/locations', OrgController.listLocations);

router.post('/locations',
  requireRole('superadmin', 'management'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2).required(), company_id: Joi.number().integer().required() }) }),
  OrgController.createLocation
);

router.put('/locations/:id',
  requireRole('superadmin', 'management'),
  celebrate({ [Segments.BODY]: Joi.object({ name: Joi.string().min(2), is_active: Joi.boolean() }) }),
  OrgController.updateLocation
);

router.delete('/locations/:id', requireRole('superadmin', 'management'), OrgController.deleteLocation);

module.exports = router;
