// Marks all existing migration files as already applied in SequelizeMeta
// Use this when tables already exist but Sequelize migration tracking is out of sync

const { Sequelize } = require('sequelize');
const fs = require('fs');
const path = require('path');

const s = new Sequelize(
  process.env.DBNAME,
  process.env.DBUSER,
  process.env.DBPASS,
  {
    host: process.env.DBHOST,
    port: parseInt(process.env.DBPORT) || 3306,
    dialect: 'mysql',
    logging: false
  }
);

async function fix() {
  try {
    await s.authenticate();
    console.log('Connected to database');

    // Create SequelizeMeta table if it doesn't exist
    await s.query(`
      CREATE TABLE IF NOT EXISTS \`SequelizeMeta\` (
        \`name\` VARCHAR(255) NOT NULL,
        UNIQUE INDEX \`name\` (\`name\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
    `);

    // Get all migration files
    const migrationsDir = path.join(__dirname, 'src', 'migrations');
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.js'))
      .sort();

    console.log(`Found ${files.length} migration files`);

    // Mark each as applied
    for (const file of files) {
      await s.query(
        'INSERT IGNORE INTO `SequelizeMeta` (`name`) VALUES (?)',
        { replacements: [file] }
      );
      console.log('Marked as done:', file);
    }

    console.log('\nAll migrations marked as applied!');
    console.log('You can now run: node seed_admin.js');
  } catch (err) {
    console.error('Error:', err.message);
  }
  process.exit(0);
}

fix();
