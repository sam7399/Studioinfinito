const express = require('express');
const router = express.Router();
const ConfigController = require('../controllers/configController');
const { authenticate, authorize } = require('../middleware/auth');

// Public read (frontend needs it on load)
router.get('/', authenticate, ConfigController.getAll);

// Superadmin only write
router.put('/:key', authenticate, authorize('superadmin'), ConfigController.update);

module.exports = router;
