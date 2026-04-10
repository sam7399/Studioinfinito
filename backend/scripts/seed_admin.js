const { User, Company } = require('../src/models');
const logger = require('../src/utils/logger');

/**
 * Create superadmin user
 * Usage: node scripts/seed_admin.js <password>
 * Example: node scripts/seed_admin.js Admin@123
 */
async function createSuperAdmin() {
  try {
    const password = process.argv[2];

    if (!password) {
      console.error('Error: Password is required');
      console.log('Usage: node scripts/seed_admin.js <password>');
      console.log('Example: node scripts/seed_admin.js Admin@123');
      process.exit(1);
    }

    if (password.length < 8) {
      console.error('Error: Password must be at least 8 characters long');
      process.exit(1);
    }

    logger.info('Creating superadmin user...');

    // Check if superadmin already exists
    const existingAdmin = await User.findOne({
      where: { email: 'admin@company.com' }
    });

    if (existingAdmin) {
      logger.warn('Superadmin user already exists');
      console.log('\nSuperadmin user already exists:');
      console.log('Email: admin@company.com');
      console.log('\nTo reset password, delete the user first or use password reset feature.');
      process.exit(0);
    }

    // Get first company (optional - superadmin doesn't need company)
    const firstCompany = await Company.findOne();

    // Create superadmin user
    const admin = await User.create({
      name: 'System Administrator',
      email: 'admin@company.com',
      password_hash: password, // Will be hashed by model hook
      role: 'superadmin',
      company_id: firstCompany ? firstCompany.id : null,
      is_active: true,
      force_password_change: true
    });

    logger.info('Superadmin user created successfully');
    
    console.log('\n✅ Superadmin user created successfully!');
    console.log('\n📧 Login Credentials:');
    console.log('   Email: admin@company.com');
    console.log(`   Password: ${password}`);
    console.log('\n⚠️  IMPORTANT:');
    console.log('   - You will be required to change your password on first login');
    console.log('   - Store these credentials securely');
    console.log('   - Delete this message after noting the credentials');
    console.log('\n🌐 Login URL:');
    console.log(`   ${process.env.BASE_URL_APP || 'https://app.gemaromatics.com'}/login`);
    console.log('');

    process.exit(0);
  } catch (error) {
    logger.error('Error creating superadmin:', error);
    console.error('\n❌ Error creating superadmin:', error.message);
    process.exit(1);
  }
}

// Run script
createSuperAdmin();