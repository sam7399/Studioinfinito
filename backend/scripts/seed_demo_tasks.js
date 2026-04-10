/**
 * Seed demo tasks assigned to demo users for testing.
 *
 * Usage:
 *   node scripts/seed_demo_tasks.js
 *
 * Assigns tasks to the 8 demo users created by seed_demo_users.js.
 * Tasks are created by the first superadmin found.
 */

const { Task, User, Department, Location, TaskActivity } = require('../src/models');
const logger = require('../src/utils/logger');

const add = (days) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
};

const DEMO_TASKS = [
  // Rahul Sharma – manager
  { email: 'rahul@gemaromatics.com', title: 'Monthly Production Report', description: 'Compile and submit monthly production metrics to management.', priority: 'high', status: 'in_progress', due_days: 3 },
  { email: 'rahul@gemaromatics.com', title: 'Team Performance Review', description: 'Conduct quarterly performance reviews for all direct reports.', priority: 'normal', status: 'open', due_days: 7 },
  { email: 'rahul@gemaromatics.com', title: 'Equipment Maintenance Schedule', description: 'Coordinate preventive maintenance for production equipment.', priority: 'urgent', status: 'open', due_days: 1 },

  // Priya Mehta – quality analyst
  { email: 'priya@gemaromatics.com', title: 'Batch QC Inspection – Lot #4821', description: 'Perform quality inspection on latest production batch.', priority: 'urgent', status: 'in_progress', due_days: 1 },
  { email: 'priya@gemaromatics.com', title: 'SOP Documentation Update', description: 'Update quality control SOPs to reflect new ISO standards.', priority: 'normal', status: 'open', due_days: 10 },

  // Amit Verma – lab technician
  { email: 'amit@gemaromatics.com', title: 'Essential Oil Distillation Test', description: 'Run distillation trials for new lavender formulation.', priority: 'high', status: 'open', due_days: 5 },
  { email: 'amit@gemaromatics.com', title: 'Equipment Calibration Log', description: 'Calibrate GC-MS and update calibration records.', priority: 'normal', status: 'in_progress', due_days: 2 },

  // Sunita Patel – accounts executive
  { email: 'sunita@gemaromatics.com', title: 'Q1 Invoice Reconciliation', description: 'Reconcile all vendor invoices for Q1 and resolve discrepancies.', priority: 'high', status: 'open', due_days: 4 },
  { email: 'sunita@gemaromatics.com', title: 'GST Filing – March 2026', description: 'Prepare and submit GST returns for the current quarter.', priority: 'urgent', status: 'open', due_days: -2 },  // overdue!

  // Deepak Joshi – department head
  { email: 'deepak@gemaromatics.com', title: 'New Vendor Evaluation', description: 'Review and shortlist new raw material suppliers.', priority: 'normal', status: 'open', due_days: 14 },

  // Kavita Singh – sales executive
  { email: 'kavita@gemaromatics.com', title: 'Client Follow-up – Naturo Organics', description: 'Follow up on pending quotation and close order.', priority: 'urgent', status: 'in_progress', due_days: 2 },
  { email: 'kavita@gemaromatics.com', title: 'Sales Target Report – Feb 2026', description: 'Submit monthly sales report with pipeline analysis.', priority: 'high', status: 'open', due_days: 3 },
  { email: 'kavita@gemaromatics.com', title: 'Trade Fair Registration', description: 'Register the company for upcoming aromatics trade fair.', priority: 'low', status: 'open', due_days: 20 },

  // Nikhil Gupta – warehouse associate
  { email: 'nikhil@gemaromatics.com', title: 'Warehouse Stock Audit', description: 'Complete physical inventory audit and update ERP stock counts.', priority: 'high', status: 'in_progress', due_days: 1 },
  { email: 'nikhil@gemaromatics.com', title: 'Dispatch Coordination – Order #7741', description: 'Coordinate timely dispatch for bulk order to Mumbai client.', priority: 'urgent', status: 'open', due_days: 0 },  // due today

  // Ananya Reddy – management
  { email: 'ananya@gemaromatics.com', title: 'Annual Strategy Review Deck', description: 'Prepare board presentation for annual strategy review.', priority: 'high', status: 'open', due_days: 12 },
];

async function seedDemoTasks() {
  try {
    console.log('\n🌱  Seeding demo tasks for GEM Aromatics Task Manager...\n');

    // Find admin/creator
    const creator = await User.findOne({ where: { role: 'superadmin' } });
    if (!creator) {
      console.error('❌  No superadmin found. Cannot seed tasks.');
      process.exit(1);
    }

    const department = await Department.findOne(
      creator.company_id ? { where: { company_id: creator.company_id } } : {}
    );
    const location = await Location.findOne(
      creator.company_id ? { where: { company_id: creator.company_id } } : {}
    );

    if (!department || !location) {
      console.error('❌  No department/location found. Please set up org structure first.');
      process.exit(1);
    }

    console.log(`👤  Creating tasks as: ${creator.name} (${creator.role})`);
    console.log(`🏬  Department : ${department.name}`);
    console.log(`📍  Location   : ${location.name}\n`);

    let created = 0;

    for (const t of DEMO_TASKS) {
      const user = await User.findOne({ where: { email: t.email } });
      if (!user) {
        console.log(`⚠️   Skipped (user not found): ${t.email}`);
        continue;
      }

      const due = add(t.due_days);
      const task = await Task.create({
        title:               t.title,
        description:         t.description,
        priority:            t.priority,
        status:              t.status,
        assigned_to_user_id: user.id,
        created_by_user_id:  creator.id,
        company_id:          creator.company_id,
        department_id:       user.department_id ?? department.id,
        location_id:         user.location_id   ?? location.id,
        due_date:            due,
      });

      await TaskActivity.create({
        task_id:       task.id,
        actor_user_id: creator.id,
        action:        'created',
        details:       `Demo task seeded for ${user.name}`,
      });

      const overdue = t.due_days < 0 ? ' ⚠️  OVERDUE' : '';
      console.log(`✅  ${user.name.padEnd(18)} | ${t.priority.padEnd(7)} | ${t.status.padEnd(20)} | ${t.title}${overdue}`);
      created++;
    }

    console.log(`\n──────────────────────────────────────────`);
    console.log(`  ${created} task(s) created.\n`);
    process.exit(0);
  } catch (err) {
    logger.error('Seed demo tasks failed:', err);
    console.error('\n❌  Error:', err.message);
    process.exit(1);
  }
}

seedDemoTasks();
