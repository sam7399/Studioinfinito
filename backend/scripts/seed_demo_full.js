/**
 * Full Demo Seed — Studio Infinito Task Manager
 *
 * Creates a complete demo environment:
 *   • 1 Demo Company  + 1 Location
 *   • 4 Departments   (HR, Finance, Operations, Marketing)
 *   • 18 Users        (Superadmin, Management, Dept Heads, Managers, Employees)
 *
 * Superadmin password is LOCKED — cannot be changed via the app.
 * All other demo passwords: Demo@1234
 *
 * Usage:
 *   node scripts/seed_demo_full.js
 *
 * Safe to re-run: existing records are skipped (no duplicates).
 */

require('dotenv').config();

const { Company, Location, Department, User, sequelize } = require('../src/models');

// ─── Credentials ────────────────────────────────────────────────────────────
const SUPERADMIN_PASSWORD = 'TSI@Demo#2025';   // LOCKED — only change via DB
const DEMO_PASSWORD       = 'Demo@1234';        // All other demo users

// ─── Org structure ───────────────────────────────────────────────────────────
const COMPANY_NAME  = 'Studio Infinito';
const LOCATION_NAME = 'Head Office';

const DEPT_NAMES = ['Human Resources', 'Finance', 'Operations', 'Marketing'];

// ─── User blueprints ─────────────────────────────────────────────────────────
// dept: null → company-level (no specific department)
const USER_BLUEPRINTS = [
  // ── Superadmin (cross-company, LOCKED password) ──────────────────────────
  {
    name:        'Demo Admin',
    email:       'admin@demo.tsi',
    username:    'demoadmin',
    role:        'superadmin',
    designation: 'System Administrator',
    emp_code:    'DEMO_SUPERADMIN',   // ← lock marker — do NOT change
    password:    SUPERADMIN_PASSWORD,
    dept:        null,
    isHead:      false,
    mgr:         null,
  },

  // ── Management ────────────────────────────────────────────────────────────
  {
    name:        'Sarah Mitchell',
    email:       'management@demo.tsi',
    username:    'sarahmitchell',
    role:        'management',
    designation: 'General Manager',
    emp_code:    'DEMO-MGT-001',
    password:    DEMO_PASSWORD,
    dept:        null,
    isHead:      false,
    mgr:         null,
  },

  // ── Human Resources ───────────────────────────────────────────────────────
  {
    name:        'David Kumar',
    email:       'hr.head@demo.tsi',
    username:    'davidkumar',
    role:        'department_head',
    designation: 'HR Director',
    emp_code:    'DEMO-HR-001',
    password:    DEMO_PASSWORD,
    dept:        'Human Resources',
    isHead:      true,
    mgr:         null,
  },
  {
    name:        'Priya Sharma',
    email:       'hr.mgr@demo.tsi',
    username:    'priyasharma',
    role:        'manager',
    designation: 'HR Manager',
    emp_code:    'DEMO-HR-002',
    password:    DEMO_PASSWORD,
    dept:        'Human Resources',
    isHead:      false,
    mgr:         'hr.head@demo.tsi',
  },
  {
    name:        'Rahul Singh',
    email:       'hr.emp1@demo.tsi',
    username:    'rahulsingh',
    role:        'employee',
    designation: 'HR Executive',
    emp_code:    'DEMO-HR-003',
    password:    DEMO_PASSWORD,
    dept:        'Human Resources',
    isHead:      false,
    mgr:         'hr.mgr@demo.tsi',
  },
  {
    name:        'Meera Patel',
    email:       'hr.emp2@demo.tsi',
    username:    'meerapatel',
    role:        'employee',
    designation: 'Recruitment Specialist',
    emp_code:    'DEMO-HR-004',
    password:    DEMO_PASSWORD,
    dept:        'Human Resources',
    isHead:      false,
    mgr:         'hr.mgr@demo.tsi',
  },

  // ── Finance ───────────────────────────────────────────────────────────────
  {
    name:        'James Wilson',
    email:       'fin.head@demo.tsi',
    username:    'jameswilson',
    role:        'department_head',
    designation: 'Finance Director',
    emp_code:    'DEMO-FIN-001',
    password:    DEMO_PASSWORD,
    dept:        'Finance',
    isHead:      true,
    mgr:         null,
  },
  {
    name:        'Anita Gupta',
    email:       'fin.mgr@demo.tsi',
    username:    'anitagupta',
    role:        'manager',
    designation: 'Finance Manager',
    emp_code:    'DEMO-FIN-002',
    password:    DEMO_PASSWORD,
    dept:        'Finance',
    isHead:      false,
    mgr:         'fin.head@demo.tsi',
  },
  {
    name:        'Rohan Verma',
    email:       'fin.emp1@demo.tsi',
    username:    'rohanverma',
    role:        'employee',
    designation: 'Accounts Executive',
    emp_code:    'DEMO-FIN-003',
    password:    DEMO_PASSWORD,
    dept:        'Finance',
    isHead:      false,
    mgr:         'fin.mgr@demo.tsi',
  },
  {
    name:        'Sunita Joshi',
    email:       'fin.emp2@demo.tsi',
    username:    'sunitajoshi',
    role:        'employee',
    designation: 'Financial Analyst',
    emp_code:    'DEMO-FIN-004',
    password:    DEMO_PASSWORD,
    dept:        'Finance',
    isHead:      false,
    mgr:         'fin.mgr@demo.tsi',
  },

  // ── Operations ────────────────────────────────────────────────────────────
  {
    name:        'Michael Chen',
    email:       'ops.head@demo.tsi',
    username:    'michaelchen',
    role:        'department_head',
    designation: 'Operations Director',
    emp_code:    'DEMO-OPS-001',
    password:    DEMO_PASSWORD,
    dept:        'Operations',
    isHead:      true,
    mgr:         null,
  },
  {
    name:        'Kavita Reddy',
    email:       'ops.mgr@demo.tsi',
    username:    'kavitareddy',
    role:        'manager',
    designation: 'Operations Manager',
    emp_code:    'DEMO-OPS-002',
    password:    DEMO_PASSWORD,
    dept:        'Operations',
    isHead:      false,
    mgr:         'ops.head@demo.tsi',
  },
  {
    name:        'Amit Nair',
    email:       'ops.emp1@demo.tsi',
    username:    'amitnair',
    role:        'employee',
    designation: 'Operations Executive',
    emp_code:    'DEMO-OPS-003',
    password:    DEMO_PASSWORD,
    dept:        'Operations',
    isHead:      false,
    mgr:         'ops.mgr@demo.tsi',
  },
  {
    name:        'Deepak Iyer',
    email:       'ops.emp2@demo.tsi',
    username:    'deepakiyer',
    role:        'employee',
    designation: 'Logistics Coordinator',
    emp_code:    'DEMO-OPS-004',
    password:    DEMO_PASSWORD,
    dept:        'Operations',
    isHead:      false,
    mgr:         'ops.mgr@demo.tsi',
  },

  // ── Marketing ─────────────────────────────────────────────────────────────
  {
    name:        'Emma Thompson',
    email:       'mkt.head@demo.tsi',
    username:    'emmathompson',
    role:        'department_head',
    designation: 'Marketing Director',
    emp_code:    'DEMO-MKT-001',
    password:    DEMO_PASSWORD,
    dept:        'Marketing',
    isHead:      true,
    mgr:         null,
  },
  {
    name:        'Nikhil Kapoor',
    email:       'mkt.mgr@demo.tsi',
    username:    'nikhilkapoor',
    role:        'manager',
    designation: 'Marketing Manager',
    emp_code:    'DEMO-MKT-002',
    password:    DEMO_PASSWORD,
    dept:        'Marketing',
    isHead:      false,
    mgr:         'mkt.head@demo.tsi',
  },
  {
    name:        'Pooja Mehta',
    email:       'mkt.emp1@demo.tsi',
    username:    'poojamehta',
    role:        'employee',
    designation: 'Content Strategist',
    emp_code:    'DEMO-MKT-003',
    password:    DEMO_PASSWORD,
    dept:        'Marketing',
    isHead:      false,
    mgr:         'mkt.mgr@demo.tsi',
  },
  {
    name:        'Arjun Das',
    email:       'mkt.emp2@demo.tsi',
    username:    'arjundas',
    role:        'employee',
    designation: 'Digital Marketing Executive',
    emp_code:    'DEMO-MKT-004',
    password:    DEMO_PASSWORD,
    dept:        'Marketing',
    isHead:      false,
    mgr:         'mkt.mgr@demo.tsi',
  },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────
function pad(str, len) { return String(str).padEnd(len); }
function roleLabel(r) {
  return { superadmin: 'Superadmin', management: 'Management', department_head: 'Dept Head',
           manager: 'Manager', employee: 'Employee' }[r] || r;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function seed() {
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  Studio Infinito — Full Demo Seed');
  console.log('══════════════════════════════════════════════════════════\n');

  // ── 1. Company ─────────────────────────────────────────────────────────────
  const [company, companyCreated] = await Company.findOrCreate({
    where: { name: COMPANY_NAME },
    defaults: { name: COMPANY_NAME, is_active: true }
  });
  console.log(`🏢  Company   : ${company.name} ${companyCreated ? '(created)' : '(already exists)'}`);

  // ── 2. Location ────────────────────────────────────────────────────────────
  const [location, locationCreated] = await Location.findOrCreate({
    where: { name: LOCATION_NAME, company_id: company.id },
    defaults: { name: LOCATION_NAME, company_id: company.id, is_active: true }
  });
  console.log(`📍  Location  : ${location.name} ${locationCreated ? '(created)' : '(already exists)'}`);

  // ── 3. Departments ─────────────────────────────────────────────────────────
  const deptMap = {};
  for (const deptName of DEPT_NAMES) {
    const [dept, deptCreated] = await Department.findOrCreate({
      where: { name: deptName, company_id: company.id },
      defaults: { name: deptName, company_id: company.id, is_active: true }
    });
    deptMap[deptName] = dept;
    console.log(`🏬  Department: ${pad(deptName, 22)} ${deptCreated ? '(created)' : '(already exists)'}`);
  }

  // ── 4. Users — Pass 1: create without manager/head refs ───────────────────
  console.log('\n──────────────────────────────────────────────────────────');
  console.log('  Creating users…');
  console.log('──────────────────────────────────────────────────────────');

  const userMap = {};   // email → User instance

  for (const bp of USER_BLUEPRINTS) {
    const dept = bp.dept ? deptMap[bp.dept] : null;

    const [user, created] = await User.findOrCreate({
      where: { email: bp.email },
      defaults: {
        name:                  bp.name,
        email:                 bp.email,
        username:              bp.username,
        password_hash:         bp.password,   // hashed by model hook
        role:                  bp.role,
        designation:           bp.designation,
        emp_code:              bp.emp_code,
        company_id:            bp.role === 'superadmin' ? null : company.id,
        department_id:         dept?.id ?? null,
        location_id:           dept ? location.id : null,
        is_active:             true,
        force_password_change: false,
      }
    });

    userMap[bp.email] = user;

    const lock = bp.emp_code === 'DEMO_SUPERADMIN' ? ' 🔒 LOCKED' : '';
    console.log(`  ${created ? '✅ Created' : '⏭  Skipped'} : ${pad(bp.name, 20)} | ${pad(roleLabel(bp.role), 14)} | ${bp.email}${lock}`);
  }

  // ── 5. Users — Pass 2: set manager_id references ──────────────────────────
  console.log('\n  Linking managers…');
  for (const bp of USER_BLUEPRINTS) {
    if (!bp.mgr) continue;
    const user = userMap[bp.email];
    const mgr  = userMap[bp.mgr];
    if (user && mgr && user.manager_id !== mgr.id) {
      await user.update({ manager_id: mgr.id });
      console.log(`  🔗 ${pad(bp.name, 20)} → manager: ${mgr.name}`);
    }
  }

  // ── 6. Departments — set department_head_id ────────────────────────────────
  console.log('\n  Linking department heads…');
  for (const bp of USER_BLUEPRINTS.filter(b => b.isHead)) {
    const headUser = userMap[bp.email];
    const dept     = deptMap[bp.dept];
    if (headUser && dept) {
      await dept.update({ department_head_id: headUser.id });
      console.log(`  👑 ${bp.dept} → head: ${headUser.name}`);
    }
  }

  // ── Summary ────────────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  DONE — Demo environment ready');
  console.log('══════════════════════════════════════════════════════════');
  console.log('\n  Login at: https://task.thestudioinfinito.com\n');
  console.log('  Role            | Email                   | Password');
  console.log('  ─────────────────────────────────────────────────────');
  for (const bp of USER_BLUEPRINTS) {
    const lock = bp.emp_code === 'DEMO_SUPERADMIN' ? ' (LOCKED)' : '';
    console.log(`  ${pad(roleLabel(bp.role), 15)} | ${pad(bp.email, 24)} | ${bp.password}${lock}`);
  }
  console.log('');
}

seed()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('\n❌ Seed failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  });
