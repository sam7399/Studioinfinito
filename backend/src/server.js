let app, config, sequelize, Sequelize, startCronJobs, stopCronJobs, logger, socketConfig;
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
  console.log('[S6] loading socket config...');
  socketConfig = require('./config/socket');
  console.log('[S7] all modules loaded');
} catch (err) {
  console.log('[REQUIRE ERROR]', err.message);
  console.log(err.stack);
  process.exit(1);
}

const PORT = config.port;

// Ensure required schema columns/tables exist via direct SQL (runs every startup).
// This is more reliable than migration-only approach.
// PostgreSQL-compatible DDL for Supabase.
async function ensureSchema() {
  const qi = sequelize.getQueryInterface();
  try {
    // Helper: add column if it doesn't exist (PostgreSQL)
    async function addColumnIfMissing(table, column, definition) {
      try {
        await sequelize.query(
          `DO $$ BEGIN
            ALTER TABLE "${table}" ADD COLUMN "${column}" ${definition};
          EXCEPTION WHEN duplicate_column THEN NULL;
          END $$;`
        );
      } catch (e) {
        console.log(`[schema] addColumn ${table}.${column} skipped:`, e.message);
      }
    }

    // Create custom enum types (PostgreSQL uses CREATE TYPE instead of ENUM inline)
    try {
      await sequelize.query(`DO $$ BEGIN CREATE TYPE chat_room_type AS ENUM ('direct','task','group'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`);
      await sequelize.query(`DO $$ BEGIN CREATE TYPE chat_message_type AS ENUM ('text','image','file','audio','system'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`);
    } catch (_) {}

    // Ensure task_reviews has rating columns (added for HR matrix)
    try {
      await addColumnIfMissing('task_reviews', 'rating', 'DECIMAL(3,1) NULL');
      await addColumnIfMissing('task_reviews', 'quality_score', 'DECIMAL(3,1) NULL');
      await addColumnIfMissing('task_reviews', 'timeliness_score', 'DECIMAL(3,1) NULL');
    } catch (e) {
      console.log('[schema] task_reviews check skipped:', e.message);
    }

    console.log('[STARTUP] ensureSchema: describing tasks table...');
    try {
      await addColumnIfMissing('tasks', 'show_collaborators', 'BOOLEAN NOT NULL DEFAULT TRUE');
      await addColumnIfMissing('tasks', 'escalation_level', 'INTEGER NOT NULL DEFAULT 0');
      await addColumnIfMissing('tasks', 'last_escalation_at', 'TIMESTAMP WITH TIME ZONE NULL');
    } catch (e) {
      console.log('[schema] tasks columns check skipped:', e.message);
    }

    // Create tables if they don't exist (PostgreSQL syntax)
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS task_assignments (
        id SERIAL PRIMARY KEY,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (task_id, user_id)
      )
    `);

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS task_dependencies (
        id SERIAL PRIMARY KEY,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        depends_on_task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (task_id, depends_on_task_id)
      )
    `);

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS task_attachments (
        id SERIAL PRIMARY KEY,
        task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        uploaded_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        original_name VARCHAR(255) NOT NULL,
        stored_name VARCHAR(255) NOT NULL,
        mime_type VARCHAR(100) NULL,
        file_size INTEGER NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      )
    `);
    try { await sequelize.query('CREATE INDEX IF NOT EXISTS idx_task_attachments_task_id ON task_attachments(task_id)'); } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS system_configs (
        id SERIAL PRIMARY KEY,
        key VARCHAR(100) NOT NULL UNIQUE,
        value TEXT NOT NULL,
        description VARCHAR(255) NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      )
    `);
    // Seed system_configs if empty
    try {
      const [rows] = await sequelize.query('SELECT COUNT(*) AS cnt FROM system_configs');
      if (parseInt(rows[0].cnt, 10) === 0) {
        await sequelize.query(`INSERT INTO system_configs (key, value, description) VALUES
          ('multi_company_users', 'false', 'Allow users to belong to multiple companies'),
          ('multi_location_users', 'false', 'Allow users to belong to multiple locations')`);
      }
    } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS user_companies (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
        is_primary BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, company_id)
      )
    `);

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS user_locations (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
        is_primary BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, location_id)
      )
    `);

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS chat_rooms (
        id SERIAL PRIMARY KEY,
        type chat_room_type NOT NULL DEFAULT 'direct',
        task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL,
        name VARCHAR(255) NULL,
        created_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        last_message_at TIMESTAMP WITH TIME ZONE NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      )
    `);
    try {
      await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_rooms_task_id ON chat_rooms(task_id)');
      await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_rooms_type ON chat_rooms(type)');
      await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_rooms_last_msg ON chat_rooms(last_message_at)');
    } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS chat_room_members (
        id SERIAL PRIMARY KEY,
        room_id INTEGER NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        last_read_at TIMESTAMP WITH TIME ZONE NULL,
        muted BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (room_id, user_id)
      )
    `);
    try { await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_room_members_user ON chat_room_members(user_id)'); } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS chat_messages (
        id SERIAL PRIMARY KEY,
        room_id INTEGER NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
        sender_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        body TEXT NOT NULL,
        message_type chat_message_type NOT NULL DEFAULT 'text',
        reply_to_id INTEGER NULL,
        edited_at TIMESTAMP WITH TIME ZONE NULL,
        deleted_at TIMESTAMP WITH TIME ZONE NULL,
        pinned_at TIMESTAMP WITH TIME ZONE NULL,
        pinned_by_user_id INTEGER NULL,
        forwarded_from_message_id INTEGER NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      )
    `);
    try {
      await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_messages_room_created ON chat_messages(room_id, created_at)');
      await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_user_id)');
      // Add self-referencing FK after table exists
      await sequelize.query(`DO $$ BEGIN
        ALTER TABLE chat_messages ADD CONSTRAINT fk_cm_reply FOREIGN KEY (reply_to_id) REFERENCES chat_messages(id) ON DELETE SET NULL;
      EXCEPTION WHEN duplicate_object THEN NULL; END $$;`);
    } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS chat_message_reactions (
        id SERIAL PRIMARY KEY,
        message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        emoji VARCHAR(16) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE (message_id, user_id, emoji)
      )
    `);
    try { await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_msg_reactions_msg ON chat_message_reactions(message_id)'); } catch (_) {}

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS chat_attachments (
        id SERIAL PRIMARY KEY,
        message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
        uploaded_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        original_name VARCHAR(255) NOT NULL,
        stored_name VARCHAR(255) NOT NULL,
        mime_type VARCHAR(100) NULL,
        file_size INTEGER NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      )
    `);
    try { await sequelize.query('CREATE INDEX IF NOT EXISTS idx_chat_attachments_msg ON chat_attachments(message_id)'); } catch (_) {}

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
      console.log('[STARTUP:7] Initializing Socket.io...');
      
      // Initialize Socket.io with HTTP server
      const io = socketConfig.initializeSocket(server);
      global.io = io; // Make io available globally
      logger.info('Socket.io initialized successfully');
      
      console.log('[STARTUP:8] Server up. Starting cron jobs...');
      startCronJobs();
      console.log('[STARTUP:9] All systems go.');
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
