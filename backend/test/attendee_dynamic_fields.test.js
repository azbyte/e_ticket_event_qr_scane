const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeAttendeeFields,
  validateAttendeeAnswers,
  splitCustomFieldAnswers,
} = require('../src/utils/eventValidation');

const fields = normalizeAttendeeFields([
  { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
  { key: 'email', label: 'Email', type: 'text', required: true },
  { key: 'phone', label: 'Nomor telepon', type: 'text', required: false },
  { key: 'organization', label: 'Instansi', type: 'text', required: false },
  { key: 'age', label: 'Usia', type: 'number', required: false },
  { key: 'visit_date', label: 'Tanggal kunjungan', type: 'date', required: false },
  {
    key: 'shirt_size',
    label: 'Ukuran kaos',
    type: 'select',
    required: true,
    options: ['S', 'M', 'L'],
  },
  { key: 'agree', label: 'Setuju syarat', type: 'checkbox', required: true },
]).fields;

const validAnswers = {
  name: 'Budi Santoso',
  email: 'budi@example.test',
  shirt_size: 'M',
  agree: true,
};

test('jawaban lengkap dan valid diterima', () => {
  assert.deepEqual(validateAttendeeAnswers(fields, validAnswers), []);
});

test('field wajib yang kosong ditolak dengan pesan yang dapat ditindaklanjuti', () => {
  const errors = validateAttendeeAnswers(fields, { email: 'budi@example.test', agree: true });
  assert.ok(errors.some((message) => /Nama lengkap.*wajib/i.test(message)));

  const noConsent = validateAttendeeAnswers(fields, { ...validAnswers, agree: false });
  assert.ok(noConsent.some((message) => /Setuju syarat.*dicentang/i.test(message)));
});

test('tipe field divalidasi: number, date, select, checkbox', () => {
  assert.ok(
    validateAttendeeAnswers(fields, { ...validAnswers, age: 'bukan-angka' })
      .some((message) => /Usia.*angka/i.test(message))
  );
  assert.ok(
    validateAttendeeAnswers(fields, { ...validAnswers, visit_date: '31-02-2026' })
      .some((message) => /Tanggal kunjungan.*tanggal/i.test(message))
  );
  assert.ok(
    validateAttendeeAnswers(fields, { ...validAnswers, shirt_size: 'XL' })
      .some((message) => /Ukuran kaos.*S, M, L/i.test(message))
  );
  assert.deepEqual(
    validateAttendeeAnswers(fields, { ...validAnswers, age: '21', visit_date: '2026-12-01' }),
    []
  );
});

test('field di luar konfigurasi event ditolak', () => {
  const errors = validateAttendeeAnswers(fields, { ...validAnswers, unknown_field: 'x' });
  assert.ok(errors.some((message) => /tidak dikenali/i.test(message)));
});

test('splitCustomFieldAnswers memisahkan kolom attendees dan custom_fields', () => {
  const { columns, customFields } = splitCustomFieldAnswers(fields, {
    ...validAnswers,
    organization: 'Universitas Negeri Padang',
    age: 21,
  });

  assert.equal(columns.name, 'Budi Santoso');
  assert.equal(columns.email, 'budi@example.test');
  assert.equal(columns.organization, undefined);
  assert.deepEqual(customFields, {
    organization: 'Universitas Negeri Padang',
    age: 21,
    shirt_size: 'M',
    agree: true,
  });
});

test('field opsional boleh kosong', () => {
  assert.deepEqual(
    validateAttendeeAnswers(fields, {
      name: 'Siti',
      email: 'siti@example.test',
      shirt_size: 'L',
      agree: true,
      phone: '',
      organization: '',
    }),
    []
  );
});
