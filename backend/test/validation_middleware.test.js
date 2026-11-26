/**
 * Regression test: `validationMiddleware` harus menyebut field yang gagal.
 *
 * express-validator v7 menghapus properti `param` pada error object sehingga
 * response lama berisi `field: undefined`. Klien (Flutter) memakai `field` dan
 * `message` untuk menjelaskan kegagalan validasi (mis. pendaftaran Organizer),
 * jadi bentuk response ini perlu dikunci oleh test.
 */
process.env.NODE_ENV = 'test';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');
const { body } = require('express-validator');

const { validationMiddleware } = require('../src/middleware/validationMiddleware');
const { registerValidator } = require('../src/validators');

const postJson = (port, urlPath, payload) =>
  new Promise((resolve, reject) => {
    const raw = JSON.stringify(payload);
    const req = http.request(
      {
        host: '127.0.0.1',
        port,
        method: 'POST',
        path: urlPath,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(raw),
        },
      },
      (res) => {
        let body_ = '';
        res.on('data', (chunk) => { body_ += chunk; });
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(body_) }));
      }
    );
    req.on('error', reject);
    req.write(raw);
    req.end();
  });

const withServer = async (buildRoutes, run) => {
  const app = express();
  app.use(express.json());
  buildRoutes(app);
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    await run(server.address().port);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
};

test('field yang gagal dilaporkan dengan nama field, bukan undefined', async () => {
  await withServer(
    (app) => {
      app.post(
        '/register',
        [...registerValidator, validationMiddleware],
        (req, res) => res.json({ success: true })
      );
    },
    async (port) => {
      const response = await postJson(port, '/register', {
        name: 'Organizer Uji',
        email: 'bukan-email',
        password: '123',
      });

      assert.equal(response.status, 400);
      assert.equal(response.body.success, false);
      assert.equal(response.body.message, 'Validation failed');
      assert.ok(Array.isArray(response.body.errors));

      const fields = response.body.errors.map((item) => item.field);
      assert.deepEqual(fields, ['email', 'password']);
      assert.ok(!fields.includes(undefined), 'field tidak boleh undefined');
      assert.match(response.body.errors[0].message, /valid email/i);
    }
  );
});

test('request valid diteruskan ke handler tanpa error', async () => {
  await withServer(
    (app) => {
      app.post(
        '/register',
        [body('email').isEmail(), validationMiddleware],
        (req, res) => res.json({ success: true })
      );
    },
    async (port) => {
      const response = await postJson(port, '/register', { email: 'organizer@example.test' });
      assert.equal(response.status, 200);
      assert.deepEqual(response.body, { success: true });
    }
  );
});
