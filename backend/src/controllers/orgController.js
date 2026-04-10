const { Company, Department, Location } = require('../models');
const logger = require('../utils/logger');

// ── Companies ────────────────────────────────────────────────────
class OrgController {
  // Companies
  static async listCompanies(req, res, next) {
    try {
      const companies = await Company.findAll({ where: { is_active: true }, order: [['name', 'ASC']] });
      res.json({ success: true, data: companies });
    } catch (err) { next(err); }
  }

  static async createCompany(req, res, next) {
    try {
      const { name, domain } = req.body;
      const company = await Company.create({ name, domain });
      logger.info(`Company created: ${name} by ${req.user.email}`);
      res.status(201).json({ success: true, data: company });
    } catch (err) {
      if (err.name === 'SequelizeUniqueConstraintError') {
        return res.status(400).json({ success: false, message: 'Company name already exists' });
      }
      next(err);
    }
  }

  static async updateCompany(req, res, next) {
    try {
      const company = await Company.findByPk(req.params.id);
      if (!company) return res.status(404).json({ success: false, message: 'Company not found' });
      await company.update(req.body);
      res.json({ success: true, data: company });
    } catch (err) { next(err); }
  }

  static async deleteCompany(req, res, next) {
    try {
      const company = await Company.findByPk(req.params.id);
      if (!company) return res.status(404).json({ success: false, message: 'Company not found' });
      await company.update({ is_active: false });
      res.json({ success: true, message: 'Company deactivated' });
    } catch (err) { next(err); }
  }

  // Departments
  static async listDepartments(req, res, next) {
    try {
      const where = { is_active: true };
      if (req.query.company_id) where.company_id = req.query.company_id;
      const departments = await Department.findAll({
        where,
        include: [{ model: Company, as: 'company', attributes: ['id', 'name'] }],
        order: [['name', 'ASC']]
      });
      res.json({ success: true, data: departments });
    } catch (err) { next(err); }
  }

  static async createDepartment(req, res, next) {
    try {
      const { name, company_id } = req.body;
      const dept = await Department.create({ name, company_id });
      logger.info(`Department created: ${name} by ${req.user.email}`);
      res.status(201).json({ success: true, data: dept });
    } catch (err) {
      if (err.name === 'SequelizeUniqueConstraintError') {
        return res.status(400).json({ success: false, message: 'Department name already exists in this company' });
      }
      next(err);
    }
  }

  static async updateDepartment(req, res, next) {
    try {
      const dept = await Department.findByPk(req.params.id);
      if (!dept) return res.status(404).json({ success: false, message: 'Department not found' });
      await dept.update(req.body);
      res.json({ success: true, data: dept });
    } catch (err) { next(err); }
  }

  static async deleteDepartment(req, res, next) {
    try {
      const dept = await Department.findByPk(req.params.id);
      if (!dept) return res.status(404).json({ success: false, message: 'Department not found' });
      await dept.update({ is_active: false });
      res.json({ success: true, message: 'Department deactivated' });
    } catch (err) { next(err); }
  }

  // Locations
  static async listLocations(req, res, next) {
    try {
      const where = { is_active: true };
      if (req.query.company_id) where.company_id = req.query.company_id;
      const locations = await Location.findAll({
        where,
        include: [{ model: Company, as: 'company', attributes: ['id', 'name'] }],
        order: [['name', 'ASC']]
      });
      res.json({ success: true, data: locations });
    } catch (err) { next(err); }
  }

  static async createLocation(req, res, next) {
    try {
      const { name, company_id } = req.body;
      const location = await Location.create({ name, company_id });
      logger.info(`Location created: ${name} by ${req.user.email}`);
      res.status(201).json({ success: true, data: location });
    } catch (err) {
      if (err.name === 'SequelizeUniqueConstraintError') {
        return res.status(400).json({ success: false, message: 'Location name already exists in this company' });
      }
      next(err);
    }
  }

  static async updateLocation(req, res, next) {
    try {
      const location = await Location.findByPk(req.params.id);
      if (!location) return res.status(404).json({ success: false, message: 'Location not found' });
      await location.update(req.body);
      res.json({ success: true, data: location });
    } catch (err) { next(err); }
  }

  static async deleteLocation(req, res, next) {
    try {
      const location = await Location.findByPk(req.params.id);
      if (!location) return res.status(404).json({ success: false, message: 'Location not found' });
      await location.update({ is_active: false });
      res.json({ success: true, message: 'Location deactivated' });
    } catch (err) { next(err); }
  }
}

module.exports = OrgController;
