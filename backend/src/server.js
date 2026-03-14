let app, config, sequelize, Sequelize, startCronJobs, stopCronJobs, logger;
try {
  console.log('[S1] loading app...');
  app = require('./app');
  console.log('[S2] loading config...');
  config = require('./config');
  console.log('[S3] loading models...');
  ({ sequelize, Sequelize } = require('./models'));
  console.log('[S4] loading cron...');
  ({ startCronJobs, stopCronJobs } = require('./cron'));
  console.log('[S5] loading logger...');
  logger = require('./utils/logger');
  console.log('[S6] all modules loaded');
} catch (err) {
  console.log('[REQUIRE ERROR]', err.message);
  console.log(err.stack);
  process.exit(1);
}

const PORT = config.port;

// Ensure required schema columns/tables exist via direct SQL (runs every startup).
// This is more reliable than migration-only approach.
async function ensureSchema() {
  const qi = sequelize.getQueryInterface();
  try {
    console.log('[STARTUP] ensureSchema: describing tasks table...');
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
          value TEXT NOT NULL,
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

    console.log('[STARTUP] ensureSchema complete');
  } catch (err) {
    console.log('[STARTUP] ensureSchema error (non-fatal):', err.message);
  }
}

let server;

// DB connect with retry — handles Railway TCP proxy cold starts and
// Render zero-downtime deploys where old instance holds connections.
async function connectWithRetry(retries = 5, delayMs = 3000) {
  for (let i = 1; i <= retries; i++) {
    try {
      console.log(`[DB] Connection attempt ${i}/${retries}...`);
      await sequelize.authenticate();
      console.log('[DB] Connected successfully');
      return; // success
    } catch (err) {
      console.log(`[DB] Attempt ${i}/${retries} failed: ${err.message}`);
      if (i < retries) {
        console.log(`[DB] Retrying in ${delayMs / 1000}s...`);
        await new Promise(r => setTimeout(r, delayMs));
      } else {
        console.log('[DB] All retries exhausted. Exiting.');
        process.exit(1);
      }
    }
  }
}

console.log('[STARTUP:3] Starting DB connection...');
connectWithRetry()
  .then(async () => {
    logger.info('Database connection established successfully');
    console.log('[STARTUP:4] DB ready, running schema check...');

    // 1. Direct schema ensure (reliable, runs every startup)
    await ensureSchema();
    console.log('[STARTUP:5] Schema check done, running migrations...');

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
      console.log('[STARTUP] Migration error (non-fatal):', err.message);
    }

    console.log('[STARTUP:6] Starting HTTP server on port', PORT);
    // 3. Start HTTP server only after DB is ready
    server = app.listen(PORT, () => {
      logger.info(`Server running on port ${PORT} in ${config.nodeEnv} mode`);
      logger.info(`API URL: ${config.urls.api}`);
      logger.info(`App URL: ${config.urls.app}`);
      console.log('[STARTUP:7] Server up. Starting cron jobs...');
      startCronJobs();
      console.log('[STARTUP:8] All systems go.');
    });
  })
  .catch(err => {
    console.log('[STARTUP] FATAL ERROR:', err.message);
    console.log(err.stack);
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
  console.log('[uncaughtException]', err.message);
  console.log(err.stack);
  gracefulShutdown('uncaughtException');
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.log('[unhandledRejection] reason:', reason instanceof Error ? reason.stack : reason);
  gracefulShutdown('unhandledRejection');
});

module.exports = () => server;
