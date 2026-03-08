const { SystemConfig } = require('../models');
const logger = require('../utils/logger');

class ConfigController {
  // GET /api/v1/config - get all config (public, needed by frontend on load)
  static async getAll(req, res) {
    try {
      const configs = await SystemConfig.findAll();
      const result = {};
      configs.forEach(c => { result[c.key] = c.value; });
      res.json({ success: true, data: result });
    } catch (err) {
      logger.error('getAll config error:', err);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }

  // PUT /api/v1/config/:key - update a config value (superadmin only)
  static async update(req, res) {
    try {
      const { key } = req.params;
      const { value } = req.body;
      if (value === undefined) return res.status(400).json({ success: false, message: 'value is required' });
      const [config, created] = await SystemConfig.findOrCreate({
        where: { key },
        defaults: { value: String(value) }
      });
      if (!created) {
        config.value = String(value);
        await config.save();
      }
      logger.info(`Config updated: ${key} = ${value} by user ${req.user?.id}`);
      res.json({ success: true, data: { key: config.key, value: config.value } });
    } catch (err) {
      logger.error('update config error:', err);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
}

module.exports = ConfigController;
