const express = require('express');
const router = express.Router();

// Import route modules
const healthRoutes = require('./health.routes');
const importRoutes = require('./import.routes');
const authRoutes = require('./auth.routes');
const taskRoutes = require('./task.routes');
const userRoutes = require('./user.routes');
const orgRoutes = require('./org.routes');
const reportRoutes = require('./report.routes');
const configRoutes = require('./config.routes');

// Health check (no auth required)
router.use('/health', healthRoutes);

// Authentication routes (no auth required)
router.use('/auth', authRoutes);

// Protected routes (auth required)
router.use('/import-export', importRoutes);
router.use('/tasks', taskRoutes);
router.use('/users', userRoutes);
router.use('/org', orgRoutes);
router.use('/reports', reportRoutes);
router.use('/config', configRoutes);

module.exports = router;