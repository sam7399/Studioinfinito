const app = require('./app');
const config = require('./config');
const { sequelize } = require('./models');
const { startCronJobs, stopCronJobs } = require('./cron');
const logger = require('./utils/logger');

const PORT = config.port;

// Test database connection and run migrations
const { Umzug, SequelizeStorage } = require('umzug');
const path = require('path');

sequelize.authenticate()
  .then(async () => {
    logger.info('Database connection established successfully');

    // Auto-run migrations on startup
    if (config.nodeEnv === 'production') {
      try {
        const umzug = new Umzug({
          migrations: {
            glob: path.join(__dirname, 'migrations/*.js'),
            resolve: ({ name, path: migPath, context }) => {
              const migration = require(migPath);
              return { name, up: async () => migration.up(context, sequelize.constructor), down: async () => migration.down(context, sequelize.constructor) };
            }
          },
          context: sequelize.getQueryInterface(),
          storage: new SequelizeStorage({ sequelize }),
          logger: { info: (msg) => logger.info('[migrate] ' + JSON.stringify(msg)) }
        });
        const pending = await umzug.pending();
        if (pending.length > 0) {
          logger.info(`Running ${pending.length} pending migration(s)...`);
          await umzug.up();
          logger.info('Migrations complete');
        }
      } catch (err) {
        logger.error('Migration error:', err.message);
      }
    }
  })
  .catch(err => {
    logger.error('Unable to connect to database:', err);
    process.exit(1);
  });

// Start server
const server = app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT} in ${config.nodeEnv} mode`);
  logger.info(`API URL: ${config.urls.api}`);
  logger.info(`App URL: ${config.urls.app}`);
  
  // Start cron jobs
  startCronJobs();
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`${signal} received. Starting graceful shutdown...`);
  
  // Stop accepting new connections
  server.close(() => {
    logger.info('HTTP server closed');
    
    // Stop cron jobs
    stopCronJobs();
    
    // Close database connection
    sequelize.close()
      .then(() => {
        logger.info('Database connection closed');
        process.exit(0);
      })
      .catch(err => {
        logger.error('Error closing database connection:', err);
        process.exit(1);
      });
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception:', err);
  gracefulShutdown('uncaughtException');
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});

module.exports = server;