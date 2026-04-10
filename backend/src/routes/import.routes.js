const express = require('express');
const multer = require('multer');
const importExportController = require('../controllers/importExportController');
const { authenticate, requireRole } = require('../middleware/auth');
const { importExportLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

// Configure multer for file uploads
const upload = multer({
  dest: 'uploads/',
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'text/csv',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ];
    
    if (allowedTypes.includes(file.mimetype) || 
        file.originalname.endsWith('.csv') || 
        file.originalname.endsWith('.xlsx')) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only CSV and XLSX files are allowed.'));
    }
  }
});

// All routes require authentication
router.use(authenticate);

// Download sample Excel template for bulk user import
router.get(
  '/users/sample',
  requireRole('superadmin', 'management'),
  importExportController.downloadUserSample
);

// User import/export (management and superadmin only)
router.post(
  '/users/import',
  requireRole('superadmin', 'management'),
  importExportLimiter,
  upload.single('file'),
  importExportController.importUsers
);

router.get(
  '/users/export',
  requireRole('superadmin', 'management'),
  importExportController.exportUsers
);

// Download sample Excel template for bulk task import
router.get(
  '/tasks/sample',
  importExportController.downloadTaskSample
);

// Task import/export
router.post(
  '/tasks/import',
  importExportLimiter,
  upload.single('file'),
  importExportController.importTasks
);

router.get(
  '/tasks/export',
  importExportController.exportTasks
);

module.exports = router;