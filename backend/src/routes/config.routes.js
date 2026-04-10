const express = require('express');
const router = express.Router();
const ConfigController = require('../controllers/configController');
const { authenticate, requireRole } = require('../middleware/auth');

// Public read (frontend needs it on load)
router.get('/', authenticate, ConfigController.getAll);

// Superadmin only write
router.put('/:key', authenticate, requireRole('superadmin'), ConfigController.update);

module.exports = router;
