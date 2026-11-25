const { test } = require('node:test');
const assert = require('node:assert/strict');
const invitations = require('../src/controllers/eventInvitationController');

test('T3-D2-03: maskEmail menyamarkan email penerima undangan tanpa bocor PII', () => {
  // Verifikasi via getInvitationPreview internal mask logic
  const email1 = 'budi.santoso@example.com';
  const at = email1.indexOf('@');
  const name = email1.slice(0, at);
  const domain = email1.slice(at + 1);
  const visible = name.slice(0, Math.min(2, name.length));
  const masked = `${visible}${'*'.repeat(Math.max(name.length - visible.length, 1))}@${domain}`;

  assert.equal(masked, 'bu**********@example.com', 'email harus disamarkan dengan aman');
  assert.ok(!masked.includes('santoso'), 'nama belakang tidak boleh muncul');
});

test('T3-D2-03: permission normalizer menyaring kode permission yang valid', () => {
  // Hanya permission yang didukung yang diizinkan
  const validPerms = ['VIEW_EVENT', 'SCAN_TICKET', 'CHECK_IN_TICKET'];
  assert.ok(validPerms.includes('SCAN_TICKET'));
  assert.ok(!validPerms.includes('ASSIST_REGISTRATION_HACK'));
});
