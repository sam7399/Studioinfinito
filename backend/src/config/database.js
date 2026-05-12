require('dotenv').config();

const sslConfig = process.env.DBSSL !== 'false' ? {
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
} : {};

module.exports = {
  development: {
    username: process.env.DBUSER || 'postgres',
    password: process.env.DBPASS || '',
    database: process.env.DBNAME || 'postgres',
    host: process.env.DBHOST || 'localhost',
    port: parseInt(process.env.DBPORT, 10) || 5432,
    dialect: 'postgres',
    timezone: '+00:00',
    logging: console.log,
    dialectOptions: sslConfig,
    define: {
      timestamps: true,
      underscored: true
    }
  },
  test: {
    username: process.env.DBUSER || 'postgres',
    password: process.env.DBPASS || '',
    database: process.env.DBNAME ? `${process.env.DBNAME}_test` : 'task_manager_test',
    host: process.env.DBHOST || 'localhost',
    port: parseInt(process.env.DBPORT, 10) || 5432,
    dialect: 'postgres',
    timezone: '+00:00',
    logging: false,
    dialectOptions: sslConfig,
    define: {
      timestamps: true,
      underscored: true
    }
  },
  production: {
    username: process.env.DBUSER,
    password: process.env.DBPASS,
    database: process.env.DBNAME,
    host: process.env.DBHOST,
    port: parseInt(process.env.DBPORT, 10) || 5432,
    dialect: 'postgres',
    timezone: '+00:00',
    logging: false,
    dialectOptions: sslConfig,
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000
    },
    define: {
      timestamps: true,
      underscored: true
    }
  }
};