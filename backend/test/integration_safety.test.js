const test = require('node:test');
const assert = require('node:assert/strict');
const { validateIntegrationTarget } = require('../scripts/integration/safety');

const safeEnvironment = {
  NODE_ENV: 'test',
  ALLOW_DESTRUCTIVE_TESTS: 'true',
  DATABASE_URL: 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test',
  TEST_API_URL: 'http://localhost:5000',
};

test('integration harness accepts only an explicitly enabled local test target', () => {
  const result = validateIntegrationTarget(safeEnvironment);
  assert.equal(result.ok, true);
  assert.equal(result.errors.length, 0);
});

test('integration harness rejects missing explicit destructive-test opt-in', () => {
  const result = validateIntegrationTarget({ ...safeEnvironment, ALLOW_DESTRUCTIVE_TESTS: 'false' });
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((error) => error.includes('ALLOW_DESTRUCTIVE_TESTS')));
});

test('integration harness rejects production and remote database targets', () => {
  for (const env of [
    { ...safeEnvironment, NODE_ENV: 'production' },
    { ...safeEnvironment, DATABASE_URL: 'postgresql://user:secret@db.example.com:5432/app' },
    { ...safeEnvironment, DATABASE_URL: 'postgresql://user:secret@db-test.example.com:5432/app_test' },
    { ...safeEnvironment, DATABASE_URL: 'postgresql://user:secret@127.0.0.1:5432/app' },
  ]) {
    assert.equal(validateIntegrationTarget(env).ok, false);
  }
});

test('integration harness rejects remote API targets', () => {
  const result = validateIntegrationTarget({ ...safeEnvironment, TEST_API_URL: 'https://api.example.com' });
  assert.equal(result.ok, false);
  assert.ok(result.errors.some((error) => error.includes('TEST_API_URL')));
});