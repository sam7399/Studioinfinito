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
    api: process.env.BASE_URL_API || 'http://localhost:26627',
    app: process.env.BASE_URL_APP || 'http://localhost:3000'
  },

  cors: {
    origins: (() => {
      // Build CORS origins from environment variables
      // Support both development and production environments
      const defaultOrigins = process.env.NODE_ENV === 'production'
        ? [] // Production must explicitly set CORS_ORIGINS
        : [
            'http://localhost:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3000',
            'http://127.0.0.1:3001'
          ];
      
      const fromEnv = process.env.CORS_ORIGINS
        ? process.env.CORS_ORIGINS.split(',').map(o => o.trim()).filter(Boolean)
        : [];
      
      return [...new Set([...defaultOrigins, ...fromEnv])];
    })()
  },

  logging: {
    level: process.env.LOG_LEVEL || 'info'
  }
};

// Validate required configuration
const requiredEnvVars = [
  'JWT_SECRET'
];

// Email vars are only required in production
if (process.env.NODE_ENV === 'production') {
  requiredEnvVars.push('EMAILHOST', 'EMAILUSER', 'EMAILPASS');
}

const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0 && process.env.NODE_ENV !== 'test') {
  console.log('[CONFIG] FATAL: Missing required environment variables:', missingVars.join(', '));
  process.exit(1);
}

// Warn about missing email config in development
if (process.env.NODE_ENV !== 'production' && process.env.NODE_ENV !== 'test') {
  const missingEmailVars = ['EMAILHOST', 'EMAILUSER', 'EMAILPASS'].filter(v => !process.env[v]);
  if (missingEmailVars.length > 0) {
    console.log('[CONFIG] WARN: Missing email configuration:', missingEmailVars.join(', '), '- Email features will be disabled.');
  }
}

module.exports = config;