/**
 * Seed demo users for testing the Create Multiple Tasks feature.
 *
 * Usage:
 *   node scripts/seed_demo_users.js
 *
 * All demo users are created with password: Demo@12345
 * They are attached to the first company, department, and location
 * found in the database.
 */

const { User, Company, Department, Location } = require('../src/models');
const logger = require('../src/utils/logger');

const DEMO_PASSWORD = 'Demo@12345';

const DEMO_USERS = [
  { name: 'Rahul Sharma',    email: 'rahul@gemaromatics.com',    role: 'manager',         designation: 'Production Manager' },
  { name: 'Priya Mehta',     email: 'priya@gemaromatics.com',    role: 'employee',        designation: 'Quality Analyst' },
  { name: 'Amit Verma',      email: 'amit@gemaromatics.com',     role: 'employee',        designation: 'Lab Technician' },
  { name: 'Sunita Patel',    email: 'sunita@gemaromatics.com',   role: 'employee',        designation: 'Accounts Executive' },
  { name: 'Deepak Joshi',    email: 'deepak@gemaromatics.com',   role: 'department_head', designation: 'Head – Operations' },
  { name: 'Kavita Singh',    email: 'kavita@gemaromatics.com',   role: 'employee',        designation: 'Sales Executive' },
  { name: 'Nikhil Gupta',    email: 'nikhil@gemaromatics.com',   role: 'employee',        designation: 'Warehouse Associate' },
  { name: 'Ananya Reddy',    email: 'ananya@gemaromatics.com',   role: 'management',      designation: 'General Manager' },
];

async function seedDemoUsers() {
  try {
    console.log('\n🌱  Seeding demo users for GEM Aromatics Task Manager...\n');

    // Fetch org data to attach users
    const company    = await Company.findOne();
    const department = await Department.findOne(
      company ? { where: { company_id: company.id } } : {}
    );
    const location   = await Location.findOne(
      company ? { where: { company_id: company.id } } : {}
    );

    if (!company) {
      console.error('❌  No company found in the database.');
      console.error('    Please create at least one company via the Organization page first.');
      process.exit(1);
    }

    console.log(`🏢  Attaching users to: ${company.name}`);
    if (department) console.log(`🏬  Department : ${department.name}`);
    if (location)   console.log(`📍  Location   : ${location.name}`);
    console.log('');

    let created = 0;
    let skipped = 0;

    for (const u of DEMO_USERS) {
      const exists = await User.findOne({ where: { email: u.email } });
      if (exists) {
        console.log(`⏭   Skipped  (already exists): ${u.name} <${u.email}>`);
        skipped++;
        continue;
      }

      await User.create({
        name:          u.name,
        email:         u.email,
        password_hash: DEMO_PASSWORD,       // hashed by model beforeCreate hook
        role:          u.role,
        designation:   u.designation,
        company_id:    company.id,
        department_id: department?.id ?? null,
        location_id:   location?.id   ?? null,
        is_active:     true,
        force_password_change: false,
      });

      console.log(`✅  Created : ${u.name.padEnd(18)} | ${u.role.padEnd(16)} | ${u.designation}`);
      created++;
    }

    console.log(`\n──────────────────────────────────────────`);
    console.log(`  ${created} user(s) created, ${skipped} skipped.`);
    console.log(`\n🔑  Login password for all demo users: ${DEMO_PASSWORD}`);
    console.log(`\n📋  Demo user list:`);
    for (const u of DEMO_USERS) {
      console.log(`    ${u.email}`);
    }
    console.log('');

    process.exit(0);
  } catch (err) {
    logger.error('Seed demo users failed:', err);
    console.error('\n❌  Error:', err.message);
    process.exit(1);
  }
}

seedDemoUsers();
