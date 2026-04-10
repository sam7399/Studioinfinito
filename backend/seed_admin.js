const { User } = require('./src/models');

async function seed() {
  try {
    await User.create({
      name: 'Super Admin',
      email: 'admin@gemaromatics.com',
      password_hash: 'Admin@123',
      role: 'superadmin',
      is_active: true,
      force_password_change: false
    });
    console.log('Admin user created successfully!');
    console.log('Email: admin@gemaromatics.com');
    console.log('Password: Admin@123');
  } catch (e) {
    if (e.name === 'SequelizeUniqueConstraintError') {
      console.log('Admin user already exists.');
    } else {
      console.error('Error:', e.message);
    }
  }
  process.exit(0);
}

seed();
