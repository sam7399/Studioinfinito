// Database Test Utilities
const Sequelize = require('sequelize');
const path = require('path');

let sequelize = null;

/**
 * Initialize test database connection
 * @returns {Promise<Object>} Sequelize instance
 */
async function initializeTestDatabase() {
  if (sequelize) {
    return sequelize;
  }

  sequelize = new Sequelize(
    process.env.TEST_DB_NAME,
    process.env.DBUSER,
    process.env.DBPASS,
    {
      host: process.env.DBHOST,
      port: process.env.DBPORT,
      dialect: 'mysql',
      logging: false,
      timestamps: true,
      underscored: true,
      pool: {
        max: 5,
        min: 1,
        idle: 10000
      }
    }
  );

  await sequelize.authenticate();
  return sequelize;
}

/**
 * Create test database
 * @returns {Promise<void>}
 */
async function createTestDatabase() {
  const tempSequelize = new Sequelize('mysql', process.env.DBUSER, process.env.DBPASS, {
    host: process.env.DBHOST,
    port: process.env.DBPORT,
    dialect: 'mysql',
    logging: false
  });

  try {
    await tempSequelize.query(`CREATE DATABASE IF NOT EXISTS \`${process.env.TEST_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
  } finally {
    await tempSequelize.close();
  }
}

/**
 * Drop test database
 * @returns {Promise<void>}
 */
async function dropTestDatabase() {
  if (sequelize) {
    await sequelize.close();
    sequelize = null;
  }

  const tempSequelize = new Sequelize('mysql', process.env.DBUSER, process.env.DBPASS, {
    host: process.env.DBHOST,
    port: process.env.DBPORT,
    dialect: 'mysql',
    logging: false
  });

  try {
    await tempSequelize.query(`DROP DATABASE IF EXISTS \`${process.env.TEST_DB_NAME}\`;`);
  } finally {
    await tempSequelize.close();
  }
}

/**
 * Sync database schema
 * @param {Object} db - Database object with models
 * @returns {Promise<void>}
 */
async function syncDatabase(db) {
  if (db && db.sequelize) {
    await db.sequelize.sync({ force: true });
  }
}

/**
 * Clear all data from tables (keep schema)
 * @param {Object} db - Database object with models
 * @returns {Promise<void>}
 */
async function clearDatabase(db) {
  if (!db || !db.sequelize) return;

  const sequelizeInstance = db.sequelize;
  const models = sequelizeInstance.models;

  // Disable foreign key checks
  await sequelizeInstance.query('SET FOREIGN_KEY_CHECKS = 0');

  // Truncate all tables
  for (const model of Object.values(models)) {
    if (model.tableName) {
      await model.destroy({ where: {}, truncate: true, cascade: true });
    }
  }

  // Re-enable foreign key checks
  await sequelizeInstance.query('SET FOREIGN_KEY_CHECKS = 1');
}

/**
 * Seed test data
 * @param {Object} db - Database object with models
 * @param {Function} seedFunction - Function to execute for seeding
 * @returns {Promise<void>}
 */
async function seedTestData(db, seedFunction) {
  if (typeof seedFunction === 'function') {
    await seedFunction(db);
  }
}

module.exports = {
  initializeTestDatabase,
  createTestDatabase,
  dropTestDatabase,
  syncDatabase,
  clearDatabase,
  seedTestData
};
