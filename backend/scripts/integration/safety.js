const isLoopback = (hostname) => ['localhost', '127.0.0.1', '::1'].includes(hostname);

const validateIntegrationTarget = (env) => {
  const errors = [];
  let database;
  let api;

  if (env.NODE_ENV !== 'test') errors.push('NODE_ENV must be exactly "test".');
  if (env.ALLOW_DESTRUCTIVE_TESTS !== 'true') {
    errors.push('Set ALLOW_DESTRUCTIVE_TESTS=true to explicitly allow fixture cleanup.');
  }
  if (!env.DATABASE_URL) {
    errors.push('DATABASE_URL must point to a dedicated local test database.');
  } else {
    try {
      database = new URL(env.DATABASE_URL);
      const databaseName = decodeURIComponent(database.pathname.replace(/^\//, '')).toLowerCase();
      const hostIsTest = isLoopback(database.hostname);
      const databaseIsTest = /(^|[-_])test($|[-_])/i.test(databaseName);
      if (!['postgres:', 'postgresql:'].includes(database.protocol)) {
        errors.push('DATABASE_URL must use PostgreSQL.');
      }
      if (!hostIsTest || !databaseIsTest) {
        errors.push('DATABASE_URL must use a loopback host and a database name marked as test.');
      }
    } catch (_) {
      errors.push('DATABASE_URL must be a valid PostgreSQL URL.');
    }
  }

  const apiUrl = env.TEST_API_URL || 'http://127.0.0.1:5000';
  try {
    api = new URL(apiUrl);
    if (api.protocol !== 'http:' || !isLoopback(api.hostname)) {
      errors.push('TEST_API_URL must be an HTTP loopback URL; remote APIs are not accepted.');
    }
  } catch (_) {
    errors.push('TEST_API_URL must be a valid URL.');
  }

  return { ok: errors.length === 0, errors, database, api };
};

module.exports = { validateIntegrationTarget };