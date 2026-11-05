const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const app = require('./src/app');
const { seedDemoAccounts } = require('./src/services/seedService');

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';
const startServer = async () => {
  try {
    await seedDemoAccounts();
    app.listen(PORT, HOST, () => {
      console.log(`Server running on http://${HOST}:${PORT}`);
      console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    console.error('Server startup or demo account seeding failed:', error.message);
    process.exitCode = 1;
  }
};

if (require.main === module) startServer();

module.exports = app;