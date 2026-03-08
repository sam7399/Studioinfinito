const { Sequelize } = require('sequelize');
const config = require('../config');

const sequelize = new Sequelize(
  config.database.name,
  config.database.user,
  config.database.password,
  {
    host: config.database.host,
    port: config.database.port,
    dialect: config.database.dialect,
    timezone: config.database.timezone,
    logging: config.database.logging,
    pool: config.database.pool || {
      max: 5,
      min: 0,
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
);

const db = {};

db.Sequelize = Sequelize;
db.sequelize = sequelize;

// Import models
db.Company = require('./company')(sequelize, Sequelize.DataTypes);
db.Department = require('./department')(sequelize, Sequelize.DataTypes);
db.Location = require('./location')(sequelize, Sequelize.DataTypes);
db.User = require('./user')(sequelize, Sequelize.DataTypes);
db.Task = require('./task')(sequelize, Sequelize.DataTypes);
db.TaskReview = require('./taskReview')(sequelize, Sequelize.DataTypes);
db.TaskActivity = require('./taskActivity')(sequelize, Sequelize.DataTypes);
db.TaskAssignment = require('./taskAssignment')(sequelize, Sequelize.DataTypes);
db.TaskDependency = require('./taskDependency')(sequelize, Sequelize.DataTypes);
db.PasswordResetToken = require('./passwordResetToken')(sequelize, Sequelize.DataTypes);
db.TaskAttachment = require('./taskAttachment')(sequelize, Sequelize.DataTypes);
db.SystemConfig = require('./systemConfig')(sequelize, Sequelize.DataTypes);
db.UserCompany = require('./userCompany')(sequelize, Sequelize.DataTypes);
db.UserLocation = require('./userLocation')(sequelize, Sequelize.DataTypes);

// Define associations
Object.keys(db).forEach(modelName => {
  if (db[modelName].associate) {
    db[modelName].associate(db);
  }
});

module.exports = db;