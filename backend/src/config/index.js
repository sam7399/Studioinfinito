require('dotenv').config();

const config = {
  port: process.env.PORT || 26627,
  nodeEnv: process.env.NODE_ENV || 'development',
  
  database: {
    host: process.env.DBHOST || 'localhost',
    name: process.env.DBNAME || 'task_manager',
    user: process.env.DBUSER || 'root',
    password: process.env.DBPASS || '',
    port: parseInt(process.env.DBPORT, 10) || 3306,
    dialect: 'mysql',
    timezone: '+00:00',
    logging: process.env.NODE_ENV === 'development' ? console.log : false
  },

  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '12h'
  },

  email: {
    host: process.env.EMAILHOST,
    port: parseInt(process.env.EMAILPORT, 10) || 587,
    secure: process.env.EMAILSECURE === 'true',
    auth: {
      user: process.env.EMAILUSER,
      pass: process.env.EMAILPASS
    },
    from: process.env.EMAIL_FROM || 'TSI Task Manager <no-reply@thestudioinfinito.com>'
  },

  urls: {
    api: process.env.BASE_URL_API || 'https://tsi-task-manager.onrender.com',
    app: process.env.BASE_URL_APP || 'https://task.thestudioinfinito.com'
  },

  cors: {
    origins: (() => {
      // Always include the known production frontends regardless of env config
      const hardcoded = [
        'https://task.thestudioinfinito.com'
      ];
      const fromEnv = process.env.CORS_ORIGINS
        ? process.env.CORS_ORIGINS.split(',').map(o => o.trim()).filter(Boolean)
        : [];
      return [...new Set([...hardcoded, ...fromEnv])];
    })()
  },

  logging: {
    level: process.env.LOG_LEVEL || 'info'
  }
};

// Validate required configuration
const requiredEnvVars = [
  'JWT_SECRET',
  'EMAILHOST',
  'EMAILUSER',
  'EMAILPASS'
];

const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0 && process.env.NODE_ENV !== 'test') {
  console.error('Missing required environment variables:', missingVars.join(', '));
  console.error('Please check your .env file');
  process.exit(1);
}

module.exports = config;