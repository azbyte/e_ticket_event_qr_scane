const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const app = require('./src/app');
const { bootstrapConfiguredAccounts } = require('./src/services/seedService');

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';
const startServer = async () => {
  try {
    const result = await bootstrapConfiguredAccounts();
    // Status saja; password/secret tidak pernah dicatat.
    if (!['SKIPPED', 'UNCHANGED'].includes(result.status)) {
      console.log(`Account bootstrap: ${result.status} - ${result.message}`);
    } else {
      console.log(`Account bootstrap: ${result.status}`);
    }
  } catch (error) {
    // Bootstrap bukan syarat hidup server: API tetap dapat melayani alur lain.
    console.error('Account bootstrap failed:', error.message);
  }

  app.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  });
};

if (require.main === module) startServer();

module.exports = app;