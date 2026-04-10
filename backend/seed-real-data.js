/**
 * seed-real-data.js
 * Resets the database and imports real user data from the 4 location Excel files.
 * Run: node seed-real-data.js
 */
require('dotenv').config();

const path = require('path');
const XLSX = require('xlsx');
const bcrypt = require('bcrypt');
const { sequelize, User, Company, Department, Location, Task, TaskActivity, TaskReview, PasswordResetToken } = require('./src/models');

const DATA_DIR = path.join(__dirname, '../frontend/data files');
const DEFAULT_PASSWORD = 'Gem@12345';

// ── Department inference from job title ───────────────────────────────────────
function inferDepartment(roleStr) {
  const r = (roleStr || '').toUpperCase().trim();
  if (r.includes('ACCOUNTS PAYABLE') || r.includes('ACCOUNT EXECUTIVE') || r.includes('BANKING') || r.includes('FINANCE')) return 'Finance & Accounts';
  if (r.includes('COMPLIANCE') || r.includes('COMPANY SECRETARY') || r.includes('SECRETARIAL')) return 'Compliance & Secretarial';
  if (r.includes('DATA ANALYST')) return 'IT & Data Analytics';
  if (r.includes('IT SUPPORT') || r === 'IT') return 'IT & Data Analytics';
  if (r.includes('IMPORT') || r.includes('EXPORT') || r.includes('EXIM')) return 'Exim';
  if (r.includes('GENERALIST') || (r.includes('HR') && !r.includes('CHARU'))) return 'Human Resources';
  if (r === 'MANAGER' || r === 'GENERAL MANAGER' || r === 'ASST. MANAGER' || r === 'ASST MANAGER' || r.includes('DEPUTY CFO') || r.includes('CEO')) return 'Management';
  if (r.includes('SENIOR MANAGER') || r.includes('SENIOR  MANAGER')) return 'Management';
  if (r.includes('DEPUTY CFO') || r.includes('CFO') || r.includes('CEO')) return 'Management';
  if (r.includes('FACTORY MANAGER') || r.includes('PRODUCTION MANAGER') || r.includes('PRODUCTION CHEMIST') || r.includes('OPERATOR')) return 'Production';
  if (r.includes('QC CHEMIST') || r.includes('QC CHEMIST') || (r.includes('QC') && !r.includes('R&D'))) return 'Quality Control';
  if (r.includes('CHEMIST') && !r.includes('R&D') && !r.includes('LAB')) return 'Quality Control';
  if (r.includes('R&D') || r.includes('LAB ATTENDANT')) return 'R&D';
  if (r.includes('REGULATORY')) return 'Regulatory';
  if (r.includes('SAFETY')) return 'Safety & Environment';
  if (r.includes('SALES')) return 'Sales';
  if (r.includes('STORE') || r.includes('LOGISTICS') || r.includes('WAREHOUSE')) return 'Store & Logistics';
  if (r.includes('PROJECT')) return 'Project Management';
  if (r.includes('MANTENANCE') || r.includes('MAINTENANCE')) return 'Maintenance';
  if (r.includes('OFFICE ASSISTANT')) return 'Administration';
  // Fallback: generic managers go to Management, everyone else Administration
  if (r.includes('MANAGER')) return 'Management';
  return 'Administration';
}

// ── System role inference from job title ──────────────────────────────────────
function inferSystemRole(roleStr, isDeptHead) {
  const r = (roleStr || '').toUpperCase().trim();
  // Top management
  if (r.includes('CEO') || r.includes('DEPUTY CFO') || r.includes('GENERAL MANAGER') ||
      r.includes('SENIOR MANAGER') || r.includes('SENIOR  MANAGER')) return 'management';
  // Department heads
  if (r.includes('FACTORY MANAGER') || r.includes('PRODUCTION MANAGER')) return 'department_head';
  // If this person appears as someone else's department head in the data → department_head
  if (isDeptHead && !r.includes('MANAGER')) return 'department_head';
  // Managers
  if (r.includes('MANAGER')) return 'manager';
  return 'employee';
}

// ── Email/name/username utilities ─────────────────────────────────────────────
function isValidEmail(e) {
  return e && e !== '-' && e.includes('@') && e.includes('.');
}

function generateUsername(name) {
  const parts = String(name || '').toLowerCase()
    .replace(/[^a-z0-9\s]/g, '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return null;
  return parts.length >= 2 ? `${parts[0]}.${parts[parts.length - 1]}` : parts[0];
}

function nameToEmail(fullName) {
  const parts = fullName.toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return null;
  if (parts.length === 1) return `${parts[0]}@gemaromatics.in`;
  return `${parts[0]}.${parts[parts.length - 1]}@gemaromatics.in`;
}

function excelDateToISO(val) {
  if (!val || val === '') return null;
  const s = String(val).trim();
  // Already a date string like "21-Dec-2001", "17.12.2001", "17-Apr-1998"
  if (/[a-zA-Z]/.test(s)) {
    try { const d = new Date(s); return isNaN(d) ? null : d.toISOString().split('T')[0]; } catch { return null; }
  }
  if (s.includes('.')) {
    // dd.mm.yyyy
    const [d, m, y] = s.split('.');
    const dt = new Date(`${y}-${m.padStart(2,'0')}-${d.padStart(2,'0')}`);
    return isNaN(dt) ? null : dt.toISOString().split('T')[0];
  }
  if (s.includes('-') && s.length === 10) {
    // yyyy-mm-dd or dd-mm-yyyy
    const parts = s.split('-');
    if (parts[0].length === 4) return s;
    const dt = new Date(`${parts[2]}-${parts[1].padStart(2,'0')}-${parts[0].padStart(2,'0')}`);
    return isNaN(dt) ? null : dt.toISOString().split('T')[0];
  }
  // Excel serial number
  const num = Number(s);
  if (!isNaN(num) && num > 10000) {
    const d = new Date((num - 25569) * 86400000);
    return isNaN(d) ? null : d.toISOString().split('T')[0];
  }
  return null;
}

function normalizePhone(val) {
  if (!val || val === '-') return null;
  const s = String(val).replace(/\s/g, '').replace(/[^0-9+]/g, '');
  return s.length >= 8 ? s.substring(0, 20) : null;
}

// ── Read user data from an Excel file ────────────────────────────────────────
function readUsersFromFile(filePath, locationName) {
  const wb = XLSX.readFile(filePath);
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
  if (rows.length < 2) return [];

  // Get headers from row 0
  const headers = rows[0].map(h => String(h).trim().toLowerCase());
  const users = [];

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    if (row.every(v => v === '' || v === null || v === undefined)) continue;

    const get = (keys) => {
      for (const k of keys) {
        const idx = headers.indexOf(k);
        if (idx !== -1 && row[idx] !== undefined && row[idx] !== '') return String(row[idx]).trim();
      }
      return '';
    };

    const fullName = get(['full name']);
    const email = get(['email']);
    const empCode = get(['emp. code', 'employee code']);
    const mobile = get(['mobile no']);
    const dob = get(['date of birth']);
    const company = get(['select company']);
    const role = get(['role']);
    const reportingManager = get(['reporting manager']);
    const departmentHead = get(['department head']);
    const password = get(['password']);

    if (!fullName || fullName === '-') continue;

    users.push({
      fullName: fullName.replace(/\s+/g, ' ').trim(),
      rawEmail: email,
      empCode: empCode && empCode !== '-' ? String(empCode).trim() : null,
      mobile: mobile,
      dob: dob,
      company: company || 'GEM AROMATICS LIMITED',
      jobTitle: role,
      reportingManagerName: reportingManager && reportingManager !== '-' ? reportingManager.trim() : null,
      departmentHeadName: departmentHead && departmentHead !== '-' ? departmentHead.trim() : null,
      locationName,
    });
  }

  return users;
}

// ── Collect all dept-head names so we can elevate their role ──────────────────
function collectDeptHeadNames(allUsers) {
  const names = new Set();
  for (const u of allUsers) {
    if (u.departmentHeadName) names.add(u.departmentHeadName.toLowerCase());
  }
  return names;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  try {
    console.log('Connecting to database...');
    await sequelize.authenticate();
    console.log('Connected.\n');

    // ── Step 1: Clear all existing data ───────────────────────────────────────
    console.log('Clearing existing data...');
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 0');
    await sequelize.query('TRUNCATE TABLE task_activities');
    await sequelize.query('TRUNCATE TABLE task_reviews');
    await sequelize.query('TRUNCATE TABLE tasks');
    await sequelize.query('TRUNCATE TABLE password_reset_tokens');
    await sequelize.query('TRUNCATE TABLE users');
    await sequelize.query('TRUNCATE TABLE departments');
    await sequelize.query('TRUNCATE TABLE locations');
    await sequelize.query('TRUNCATE TABLE companies');
    await sequelize.query('SET FOREIGN_KEY_CHECKS = 1');
    console.log('All tables cleared.\n');

    // ── Step 2: Create company ─────────────────────────────────────────────────
    const company = await Company.create({ name: 'GEM AROMATICS LIMITED' });
    console.log('Created company:', company.name);

    // ── Step 3: Create locations ───────────────────────────────────────────────
    const locationNames = ['Mumbai', 'Budaun', 'Silvassa', 'Taloja'];
    const locationMap = {};
    for (const name of locationNames) {
      const loc = await Location.create({ name, company_id: company.id });
      locationMap[name.toLowerCase()] = loc.id;
    }
    console.log('Created locations:', locationNames.join(', '));

    // ── Step 4: Create departments ─────────────────────────────────────────────
    const deptNames = [
      'Management',
      'Finance & Accounts',
      'Compliance & Secretarial',
      'IT & Data Analytics',
      'Exim',
      'Human Resources',
      'Production',
      'Quality Control',
      'R&D',
      'Regulatory',
      'Safety & Environment',
      'Sales',
      'Store & Logistics',
      'Project Management',
      'Maintenance',
      'Administration',
    ];
    const deptMap = {};
    for (const name of deptNames) {
      const dept = await Department.create({ name, company_id: company.id });
      deptMap[name] = dept.id;
    }
    console.log('Created', deptNames.length, 'departments.\n');

    // ── Step 5: Read all user data from Excel files ───────────────────────────
    const files = [
      { file: 'Mumbai Task List - User List-1.xlsx', location: 'Mumbai' },
      { file: 'Budaun Task List - User List.xlsx', location: 'Budaun' },
      { file: 'Silvassa Task List - User List.xlsx', location: 'Silvassa' },
      { file: 'Taloja Task List - User List.xlsx', location: 'Taloja' },
    ];

    let allRawUsers = [];
    for (const f of files) {
      const filePath = path.join(DATA_DIR, f.file);
      const users = readUsersFromFile(filePath, f.location);
      console.log(`Read ${users.length} users from ${f.file}`);
      allRawUsers = allRawUsers.concat(users);
    }
    console.log(`Total raw users: ${allRawUsers.length}\n`);

    // ── Step 6: Add the two owner/founder users manually ─────────────────────
    const ownerUsers = [
      { fullName: 'Yash Parekh', rawEmail: 'yash@gemaromatics.in', jobTitle: 'Director', locationName: 'Mumbai', company: 'GEM AROMATICS LIMITED', empCode: null, mobile: null, dob: null, reportingManagerName: null, departmentHeadName: null },
      { fullName: 'Kaksha Parekh', rawEmail: 'kaksha@gemaromatics.in', jobTitle: 'Director', locationName: 'Mumbai', company: 'GEM AROMATICS LIMITED', empCode: null, mobile: null, dob: null, reportingManagerName: null, departmentHeadName: null },
      { fullName: 'Vipul Parekh', rawEmail: 'vipul@gemaromatics.in', jobTitle: 'Director', locationName: 'Mumbai', company: 'GEM AROMATICS LIMITED', empCode: null, mobile: null, dob: null, reportingManagerName: null, departmentHeadName: null },
    ];
    allRawUsers = [...ownerUsers, ...allRawUsers];

    // ── Step 7: Collect dept-head names to elevate roles ─────────────────────
    const deptHeadNames = collectDeptHeadNames(allRawUsers);

    // ── Step 8: Resolve emails (deduplicate) ──────────────────────────────────
    const seenEmails = new Set();
    const seenEmpCodes = new Set();
    const seenUsernames = new Set();

    function uniqueEmail(baseEmail) {
      if (!seenEmails.has(baseEmail)) return baseEmail;
      let i = 2;
      while (seenEmails.has(`${baseEmail.split('@')[0]}${i}@${baseEmail.split('@')[1]}`)) i++;
      return `${baseEmail.split('@')[0]}${i}@${baseEmail.split('@')[1]}`;
    }

    function uniqueUsername(base) {
      if (!seenUsernames.has(base)) return base;
      let i = 2;
      while (seenUsernames.has(`${base}${i}`)) i++;
      return `${base}${i}`;
    }

    const preparedUsers = [];
    for (const u of allRawUsers) {
      // Resolve email
      let email;
      if (isValidEmail(u.rawEmail)) {
        const cleaned = u.rawEmail.toLowerCase().trim();
        email = uniqueEmail(cleaned);
      } else {
        // Generate from emp_code or name
        const nameEmail = nameToEmail(u.fullName);
        email = nameEmail ? uniqueEmail(nameEmail) : null;
      }
      if (!email) {
        console.warn(`  SKIP: No email for "${u.fullName}"`);
        continue;
      }
      seenEmails.add(email);

      // Resolve emp_code
      let empCode = null;
      if (u.empCode && !seenEmpCodes.has(u.empCode)) {
        empCode = u.empCode;
        seenEmpCodes.add(u.empCode);
      }

      // Generate unique username
      const usernameBase = generateUsername(u.fullName);
      const username = usernameBase ? uniqueUsername(usernameBase) : null;
      if (username) seenUsernames.add(username);

      // Infer department and system role
      const isDeptHead = deptHeadNames.has(u.fullName.toLowerCase());
      const dept = inferDepartment(u.jobTitle);
      // Owners/Directors always superadmin
      const sysRole = (u.jobTitle === 'Director')
        ? 'superadmin'
        : inferSystemRole(u.jobTitle, isDeptHead);

      preparedUsers.push({
        name: u.fullName,
        email,
        username,
        password_hash: DEFAULT_PASSWORD,
        role: sysRole,
        designation: u.jobTitle || null,
        emp_code: empCode,
        phone: normalizePhone(u.mobile),
        date_of_birth: excelDateToISO(u.dob),
        company_id: company.id,
        department_id: deptMap[dept] || deptMap['Administration'],
        location_id: locationMap[u.locationName.toLowerCase()] || null,
        is_active: true,
        force_password_change: true,
        // Store manager name for second pass
        _reportingManagerName: u.reportingManagerName,
        _departmentHeadName: u.departmentHeadName,
      });
    }

    console.log(`Prepared ${preparedUsers.length} users for insertion.\n`);

    // ── Step 9: First pass — create all users ─────────────────────────────────
    console.log('Creating users...');
    const createdUsers = [];
    let successCount = 0, errorCount = 0;

    for (const userData of preparedUsers) {
      const { _reportingManagerName, _departmentHeadName, ...data } = userData;
      try {
        const user = await User.create(data);
        createdUsers.push({ user, _reportingManagerName, _departmentHeadName });
        successCount++;
      } catch (err) {
        console.warn(`  FAIL: ${userData.name} (${userData.email}) — ${err.message}`);
        errorCount++;
      }
    }
    console.log(`  Created: ${successCount}  Failed: ${errorCount}\n`);

    // ── Step 10: Second pass — link managers and department heads ─────────────
    console.log('Linking reporting managers and department heads...');

    // Build name→id and email→id maps
    const nameToId = {};
    const emailToId = {};
    for (const { user } of createdUsers) {
      nameToId[user.name.toLowerCase()] = user.id;
      emailToId[user.email.toLowerCase()] = user.id;
    }

    // Fuzzy match: try to find a user by partial name
    function findUserId(nameStr) {
      if (!nameStr) return null;
      const lower = nameStr.toLowerCase().trim();
      // Exact match
      if (nameToId[lower]) return nameToId[lower];
      // Partial: see if any known name starts with or contains the search string
      for (const [n, id] of Object.entries(nameToId)) {
        if (n.includes(lower) || lower.includes(n.split(' ')[0])) return id;
      }
      return null;
    }

    let linkedManagers = 0, linkedDeptHeads = 0;
    for (const { user, _reportingManagerName, _departmentHeadName } of createdUsers) {
      const updates = {};
      const managerId = findUserId(_reportingManagerName);
      if (managerId && managerId !== user.id) {
        updates.manager_id = managerId;
        linkedManagers++;
      }
      const deptHeadId = findUserId(_departmentHeadName);
      if (deptHeadId && deptHeadId !== user.id) {
        updates.department_head_id = deptHeadId;
        linkedDeptHeads++;
      }
      if (Object.keys(updates).length > 0) {
        await user.update(updates);
      }
    }
    console.log(`  Linked managers: ${linkedManagers}  Linked dept heads: ${linkedDeptHeads}\n`);

    // ── Summary ───────────────────────────────────────────────────────────────
    const totalUsers = await User.count();
    console.log('='.repeat(60));
    console.log('SEED COMPLETE');
    console.log('='.repeat(60));
    console.log(`Company : 1`);
    console.log(`Locations: ${locationNames.length} (${locationNames.join(', ')})`);
    console.log(`Departments: ${deptNames.length}`);
    console.log(`Users created: ${totalUsers}`);
    console.log(`Default password: ${DEFAULT_PASSWORD}`);
    console.log(`All users will be prompted to change password on first login.`);
    console.log('='.repeat(60));

    // Print login info for key users
    const keyUsers = await User.findAll({
      where: { role: ['superadmin', 'management'] },
      attributes: ['name', 'email', 'role', 'designation'],
      order: [['role', 'ASC'], ['name', 'ASC']]
    });
    const allKeyUsers = await User.findAll({
      where: { role: ['superadmin', 'management'] },
      attributes: ['name', 'email', 'username', 'role', 'designation'],
      order: [['role', 'ASC'], ['name', 'ASC']]
    });
    console.log('\nKey accounts (superadmin / management):');
    for (const u of allKeyUsers) {
      console.log(`  [${u.role}] ${u.name} | email: ${u.email} | username: ${u.username || 'N/A'} | ${u.designation || ''}`);
    }

    process.exit(0);
  } catch (err) {
    console.error('Seed failed:', err);
    process.exit(1);
  }
}

main();
