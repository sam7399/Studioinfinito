require('dotenv').config();

module.exports = {
  development: {
    username: process.env.DBUSER || 'root',
    password: process.env.DBPASS || '',
    database: process.env.DBNAME || 'task_manager',
    host: process.env.DBHOST || 'localhost',
    port: parseInt(process.env.DBPORT, 10) || 3306,
    dialect: 'mysql',
    timezone: '+00:00',
    logging: console.log,
    define: {
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci',
      timestamps: true,
      underscored: true
    }
  },
  test: {
    username: process.env.DBUSER || 'root',
    password: process.env.DBPASS || '',
    database: process.env.DBNAME ? `${process.env.DBNAME}_test` : 'task_manager_test',
    host: process.env.DBHOST || 'localhost',
    port: parseInt(process.env.DBPORT, 10) || 3306,
    dialect: 'mysql',
    timezone: '+00:00',
    logging: false,
    define: {
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci',
      timestamps: true,
      underscored: true
    }
  },
  production: {
    username: process.env.DBUSER,
    password: process.env.DBPASS,
    database: process.env.DBNAME,
    host: process.env.DBHOST,
    port: parseInt(process.env.DBPORT, 10) || 3306,
    dialect: 'mysql',
    timezone: '+00:00',
    logging: false,
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000
    },
    define: {
      charset: 'utf8mb4',
      collate: 'utf8mb4_unicode_ci',
      timestamps: true,
      underscored: true
    }
  }
};