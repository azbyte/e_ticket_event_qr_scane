'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const SCRIPT = path.resolve(__dirname, 'validate-sync-config.js');

function writeTmpConfig(content) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'synctest-'));
  const file = path.join(dir, 'config.yaml');
  fs.writeFileSync(file, content, 'utf8');
  return file;
}

function cleanup(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
}

function run(args) {
  try {
    const stdout = execFileSync(process.execPath, [SCRIPT, ...args], {
      encoding: 'utf8',
      maxBuffer: 1024 * 1024,
    });
    return { code: 0, stdout, stderr: '' };
  } catch (err) {
    return {
      code: err.status == null ? 1 : err.status,
      stdout: Buffer.from(err.stdout || '').toString('utf8'),
      stderr: Buffer.from(err.stderr || '').toString('utf8'),
    };
  }
}

test('valid config is accepted (exit 0)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n    - Developer-2\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 0);
    assert.ok(res.stdout.includes('OK: konfigurasi sinkronisasi valid'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('hash in branch name is preserved while YAML comments are ignored', () => {
  const file = writeTmpConfig('sources:\n  main: # source comment\n    - feature#42 # child comment\n');
  try {
    const validated = run(['validate', file]);
    const children = run(['children', 'main', file]);
    assert.strictEqual(validated.code, 0);
    assert.deepStrictEqual(children.stdout.trim().split('\n'), ['feature#42']);
  } finally {
    cleanup(path.dirname(file));
  }
});

test('duplicate child is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n    - Developer-1\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('duplicate child'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('duplicate source is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n  main:\n    - Developer-2\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('duplicate source'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('main cannot be configured as a child (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  release:\n    - main\n  main:\n    - Developer-1\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('main'));
    assert.ok((res.stdout + res.stderr).includes('child sinkronisasi'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('invalid Git branch names are rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - -f\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('bukan branch Git yang valid'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('multiple parent is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n  Developer-2:\n    - Developer-1\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('multiple parent'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('self-reference is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - main\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('self-reference'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('cycle is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n  Developer-1:\n    - main\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
    assert.ok((res.stdout + res.stderr).includes('siklus'));
  } finally {
    cleanup(path.dirname(file));
  }
});

test('invalid structure/indent is rejected (exit 1)', () => {
  const file = writeTmpConfig('sources:\n  main:\n      - Developer-1\n');
  try {
    const res = run(['validate', file]);
    assert.strictEqual(res.code, 1);
  } finally {
    cleanup(path.dirname(file));
  }
});

test('children returns direct children of source', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n    - Developer-2\n    - Developer-3\n');
  try {
    const res = run(['children', 'main', file]);
    assert.strictEqual(res.code, 0);
    const children = res.stdout.trim().split('\n');
    assert.deepStrictEqual(children, ['Developer-1', 'Developer-2', 'Developer-3']);
  } finally {
    cleanup(path.dirname(file));
  }
});

test('non-source returns SOURCE_NOT_CONFIGURED (exit 0)', () => {
  const file = writeTmpConfig('sources:\n  main:\n    - Developer-1\n');
  try {
    const res = run(['children', 'Developer-1', file]);
    assert.strictEqual(res.code, 0);
    assert.strictEqual(res.stdout.trim(), 'SKIPPED: SOURCE_NOT_CONFIGURED');
  } finally {
    cleanup(path.dirname(file));
  }
});

test('source without children returns NO_DIRECT_CHILDREN (exit 0)', () => {
  const file = writeTmpConfig('sources:\n  Leaf:\n');
  try {
    const res = run(['children', 'Leaf', file]);
    assert.strictEqual(res.code, 0);
    assert.strictEqual(res.stdout.trim(), 'SKIPPED: NO_DIRECT_CHILDREN');
  } finally {
    cleanup(path.dirname(file));
  }
});

test('missing config file exits 2', () => {
  const res = run(['validate', path.join(os.tmpdir(), 'does-not-exist-sync-config.yaml')]);
  assert.strictEqual(res.code, 2);
});
