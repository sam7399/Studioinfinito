const app = require('./app');
const config = require('./config');
const { sequelize, Sequelize } = require('./models');
const { startCronJobs, stopCronJobs } = require('./cron');
const logger = require('./utils/logger');

const PORT = config.port;

// Ensure required schema columns/tables exist via direct SQL (runs every startup).
// This is more reliable than migration-only approach.
async function ensureSchema() {
  const qi = sequelize.getQueryInterface();
  try {
    const cols = await qi.describeTable('tasks');

    if (!cols.show_collaborators) {
      await sequelize.query('ALTER TABLE tasks ADD COLUMN show_collaborators TINYINT(1) NOT NULL DEFAULT 1');
      logger.info('[schema] Added column show_collaborators');
    }
    if (!cols.escalation_level) {
      await sequelize.query('ALTER TABLE tasks ADD COLUMN escalation_level INT NOT NULL DEFAULT 0');
      logger.info('[schema] Added column escalation_level');
    }
    if (!cols.last_escalation_at) {
      await sequelize.query('ALTER TABLE tasks ADD COLUMN last_escalation_at DATETIME NULL');
      logger.info('[schema] Added column last_escalation_at');
    }

    const tables = await qi.showAllTables();

    if (!tables.includes('task_assignments')) {
      await sequelize.query(`
        CREATE TABLE task_assignments (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          task_id INT NOT NULL,
          user_id INT NOT NULL,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          CONSTRAINT fk_ta_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT fk_ta_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
          UNIQUE KEY ta_task_user_unique (task_id, user_id)
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      logger.info('[schema] Created table task_assignments');
    }

    if (!tables.includes('task_dependencies')) {
      await sequelize.query(`
        CREATE TABLE task_dependencies (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          task_id INT NOT NULL,
          depends_on_task_id INT NOT NULL,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          CONSTRAINT fk_td_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT fk_td_dep FOREIGN KEY (depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE ON UPDATE CASCADE,
          UNIQUE KEY td_unique (task_id, depends_on_task_id)
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      logger.info('[schema] Created table task_dependencies');
    }

    if (!tables.includes('task_attachments')) {
      await sequelize.query(`
        CREATE TABLE task_attachments (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          task_id INT NOT NULL,
          uploaded_by_user_id INT NOT NULL,
          original_name VARCHAR(255) NOT NULL,
          stored_name VARCHAR(255) NOT NULL,
          mime_type VARCHAR(100) NULL,
          file_size INT NULL,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          CONSTRAINT fk_attach_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT fk_attach_user FOREIGN KEY (uploaded_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
          KEY ta_attach_task_id_idx (task_id)
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      logger.info('[schema] Created table task_attachments');
    }

    if (!tables.includes('system_configs')) {
      await sequelize.query(`
        CREATE TABLE system_configs (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          \`key\` VARCHAR(100) NOT NULL UNIQUE,
          value TEXT NOT NULL DEFAULT 'false',
          description VARCHAR(255) NULL,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      await sequelize.query(`INSERT INTO system_configs (\`key\`, value, description) VALUES
        ('multi_company_users', 'false', 'Allow users to belong to multiple companies'),
        ('multi_location_users', 'false', 'Allow users to belong to multiple locations')`);
      logger.info('[schema] Created table system_configs');
    }

    if (!tables.includes('user_companies')) {
      await sequelize.query(`
        CREATE TABLE user_companies (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          company_id INT NOT NULL,
          is_primary TINYINT(1) NOT NULL DEFAULT 0,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          CONSTRAINT fk_uc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT fk_uc_company FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE ON UPDATE CASCADE,
          UNIQUE KEY uc_user_company_unique (user_id, company_id)
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      logger.info('[schema] Created table user_companies');
    }

    if (!tables.includes('user_locations')) {
      await sequelize.query(`
        CREATE TABLE user_locations (
          id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          location_id INT NOT NULL,
          is_primary TINYINT(1) NOT NULL DEFAULT 0,
          created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          CONSTRAINT fk_ul_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT fk_ul_location FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE ON UPDATE CASCADE,
          UNIQUE KEY ul_user_location_unique (user_id, location_id)
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      `);
      logger.info('[schema] Created table user_locations');
    }

    logger.info('[schema] Schema check complete');
  } catch (err) {
    logger.error('[schema] Schema ensure error:', err.message);
  }
}

let server;

sequelize.authenticate()
  .then(async () => {
    logger.info('Database connection established successfully');

    // 1. Direct schema ensure (reliable, runs every startup)
    await ensureSchema();

    // 2. Umzug migrations for any remaining pending migrations
    try {
      const { Umzug, SequelizeStorage } = require('umzug');
      const path = require('path');
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
      logger.error('Migration error (non-fatal):', err.message);
    }

    // 3. Start HTTP server only after DB is ready
    server = app.listen(PORT, () => {
      logger.info(`Server running on port ${PORT} in ${config.nodeEnv} mode`);
      logger.info(`API URL: ${config.urls.api}`);
      logger.info(`App URL: ${config.urls.app}`);
      startCronJobs();
    });
  })
  .catch(err => {
    logger.error('Unable to connect to database:', err);
    process.exit(1);
  });

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`${signal} received. Starting graceful shutdown...`);

  // Stop accepting new connections
  const closeServer = (cb) => server ? server.close(cb) : cb();
  closeServer(() => {
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

module.exports = () => server;