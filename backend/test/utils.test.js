const test = require('node:test');
const assert = require('node:assert/strict');
const { successResponse, errorResponse } = require('../src/utils/response');
const { TICKET_STATUS, USER_ROLES, HTTP_STATUS } = require('../src/utils/constants');

function responseRecorder() {
  return {
    statusCode: undefined,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('successResponse returns the standard success envelope and defaults', () => {
  const response = responseRecorder();
  assert.equal(successResponse(response, { id: 'synthetic' }), response);
  assert.equal(response.statusCode, HTTP_STATUS.OK);
  assert.deepEqual(response.body, {
    success: true,
    message: 'Success',
    data: { id: 'synthetic' },
  });
});

test('successResponse honors an explicit message and status', () => {
  const response = responseRecorder();
  successResponse(response, null, 'Ticket created', HTTP_STATUS.CREATED);
  assert.equal(response.statusCode, HTTP_STATUS.CREATED);
  assert.equal(response.body.message, 'Ticket created');
});

test('errorResponse omits optional errors when absent', () => {
  const response = responseRecorder();
  errorResponse(response, 'Not found', HTTP_STATUS.NOT_FOUND);
  assert.equal(response.statusCode, HTTP_STATUS.NOT_FOUND);
  assert.deepEqual(response.body, { success: false, message: 'Not found' });
});

test('errorResponse includes supplied validation errors', () => {
  const response = responseRecorder();
  errorResponse(response, 'Invalid input', HTTP_STATUS.BAD_REQUEST, [{ field: 'email' }]);
  assert.deepEqual(response.body, {
    success: false,
    message: 'Invalid input',
    errors: [{ field: 'email' }],
  });
});

test('ticket and role constants expose expected project values', () => {
  assert.equal(TICKET_STATUS.ACTIVE, 'active');
  assert.equal(TICKET_STATUS.USED, 'used');
  assert.equal(USER_ROLES.ORGANIZER, 'organizer');
  assert.equal(USER_ROLES.ADMIN, 'admin');
});