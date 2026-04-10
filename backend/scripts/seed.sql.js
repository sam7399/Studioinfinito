const { Company, Department, Location } = require('../src/models');
const logger = require('../src/utils/logger');

/**
 * Seed base data: Companies, Departments, Locations
 * This script is idempotent - safe to run multiple times
 */
async function seedBaseData() {
  try {
    logger.info('Starting base data seeding...');

    // Seed Companies
    const companies = [
      { name: 'Gem Aromatics', domain: 'https://gemaromatics.com', is_active: true },
      { name: 'Demo Company', domain: null, is_active: true }
    ];

    for (const companyData of companies) {
      const [company, created] = await Company.findOrCreate({
        where: { name: companyData.name },
        defaults: companyData
      });
      
      if (created) {
        logger.info(`Created company: ${company.name}`);
      } else {
        logger.info(`Company already exists: ${company.name}`);
      }
    }

    // Get Gem Aromatics company
    const gemAromatics = await Company.findOne({ where: { name: 'Gem Aromatics' } });

    if (gemAromatics) {
      // Seed Departments for Gem Aromatics
      const departments = [
        { company_id: gemAromatics.id, name: 'Sales', is_active: true },
        { company_id: gemAromatics.id, name: 'Marketing', is_active: true },
        { company_id: gemAromatics.id, name: 'Operations', is_active: true },
        { company_id: gemAromatics.id, name: 'Finance', is_active: true },
        { company_id: gemAromatics.id, name: 'IT', is_active: true },
        { company_id: gemAromatics.id, name: 'HR', is_active: true }
      ];

      for (const deptData of departments) {
        const [dept, created] = await Department.findOrCreate({
          where: { company_id: deptData.company_id, name: deptData.name },
          defaults: deptData
        });
        
        if (created) {
          logger.info(`Created department: ${dept.name}`);
        } else {
          logger.info(`Department already exists: ${dept.name}`);
        }
      }

      // Seed Locations for Gem Aromatics
      const locations = [
        { company_id: gemAromatics.id, name: 'Head Office', is_active: true },
        { company_id: gemAromatics.id, name: 'Warehouse', is_active: true },
        { company_id: gemAromatics.id, name: 'Branch Office', is_active: true },
        { company_id: gemAromatics.id, name: 'Remote', is_active: true }
      ];

      for (const locData of locations) {
        const [loc, created] = await Location.findOrCreate({
          where: { company_id: locData.company_id, name: locData.name },
          defaults: locData
        });
        
        if (created) {
          logger.info(`Created location: ${loc.name}`);
        } else {
          logger.info(`Location already exists: ${loc.name}`);
        }
      }
    }

    // Get Demo Company
    const demoCompany = await Company.findOne({ where: { name: 'Demo Company' } });

    if (demoCompany) {
      // Seed basic departments for Demo Company
      const demoDepartments = [
        { company_id: demoCompany.id, name: 'General', is_active: true }
      ];

      for (const deptData of demoDepartments) {
        const [dept, created] = await Department.findOrCreate({
          where: { company_id: deptData.company_id, name: deptData.name },
          defaults: deptData
        });
        
        if (created) {
          logger.info(`Created department: ${dept.name}`);
        }
      }

      // Seed basic location for Demo Company
      const demoLocations = [
        { company_id: demoCompany.id, name: 'Main Office', is_active: true }
      ];

      for (const locData of demoLocations) {
        const [loc, created] = await Location.findOrCreate({
          where: { company_id: locData.company_id, name: locData.name },
          defaults: locData
        });
        
        if (created) {
          logger.info(`Created location: ${loc.name}`);
        }
      }
    }

    logger.info('Base data seeding completed successfully');
    process.exit(0);
  } catch (error) {
    logger.error('Error seeding base data:', error);
    process.exit(1);
  }
}

// Run seeding
seedBaseData();