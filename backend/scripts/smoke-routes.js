/* eslint-disable no-console */
// Smoke test regresi konsolidasi router: setiap endpoint harus tetap TERDAFTAR.
// Status 401/403/400/200/409 semuanya berarti route ada; hanya 404 yang gagal.
require('dotenv').config();

const API = process.env.API_BASE || 'http://127.0.0.1:5000/api';

// [method, path, body?] — path memakai id dummy; yang diuji keberadaan route.
const endpoints = [
  ['POST', '/auth/login', { email: 'x@y.z', password: 'x' }],
  ['POST', '/auth/register', {}],
  ['GET', '/auth/me'],
  ['PUT', '/auth/me', {}],
  ['POST', '/auth/logout'],
  ['GET', '/me/memberships'],
  ['GET', '/events/public'],
  ['GET', '/events'],
  ['GET', '/events/mine'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000'],
  ['POST', '/events', {}],
  ['PUT', '/events/00000000-0000-0000-0000-000000000000', {}],
  ['DELETE', '/events/00000000-0000-0000-0000-000000000000'],
  ['POST', '/events/00000000-0000-0000-0000-000000000000/publish'],
  ['POST', '/events/00000000-0000-0000-0000-000000000000/submit-review'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/summary'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/sales'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/attendees'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/attendees/export'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/orders'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/members'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/ticket-types'],
  ['GET', '/events/00000000-0000-0000-0000-000000000000/invitations'],
  ['GET', '/ticket-types/00000000-0000-0000-0000-000000000000'],
  ['GET', '/invitations/me'],
  ['GET', '/invitations/sometoken'],
  ['POST', '/invitations/sometoken/accept'],
  ['POST', '/orders', {}],
  ['GET', '/orders'],
  ['GET', '/orders/00000000-0000-0000-0000-000000000000'],
  ['GET', '/payments/00000000-0000-0000-0000-000000000000'],
  ['POST', '/payments/simulate', {}],
  ['GET', '/tickets/my-tickets'],
  ['GET', '/tickets/00000000-0000-0000-0000-000000000000'],
  ['POST', '/tickets/00000000-0000-0000-0000-000000000000/email'],
  ['POST', '/tickets/validate', {}],
  ['POST', '/tickets/verify', {}],
  ['POST', '/check-ins', {}],
  ['GET', '/check-ins/events/00000000-0000-0000-0000-000000000000/check-ins'],
  ['POST', '/check-ins/sync', {}],
  ['GET', '/admin/accounts'],
  ['GET', '/admin/organizers'],
  ['PUT', '/admin/accounts/00000000-0000-0000-0000-000000000000/status', {}],
  ['PUT', '/admin/events/00000000-0000-0000-0000-000000000000/moderation', {}],
  ['GET', '/admin/audit-logs'],
  ['GET', '/admin/settings'],
  ['PUT', '/admin/settings/key', { value: 'x' }],
  ['GET', '/admin/overview'],
  ['GET', '/admin/subscriptions'],
  ['POST', '/admin/email/retry', {}],
  ['GET', '/plans'],
  ['GET', '/plans/admin/all'],
  ['GET', '/plans/00000000-0000-0000-0000-000000000000'],
  ['POST', '/plans/admin', {}],
  ['PUT', '/plans/admin/00000000-0000-0000-0000-000000000000', {}],
  ['DELETE', '/plans/admin/00000000-0000-0000-0000-000000000000'],
  ['GET', '/subscriptions/me'],
  ['POST', '/subscriptions', {}],
  ['POST', '/subscriptions/cancel'],
  ['GET', '/subscriptions/payments'],
  ['GET', '/revenue/me'],
  ['GET', '/revenue/admin/summary'],
  ['GET', '/revenue/admin/transactions'],
  ['GET', '/support-reports'],
  ['POST', '/support-reports', {}],
  ['GET', '/support-reports/00000000-0000-0000-0000-000000000000'],
  ['PUT', '/support-reports/00000000-0000-0000-0000-000000000000/status', {}],
  ['POST', '/support-reports/00000000-0000-0000-0000-000000000000/status', {}],
  ['PUT', '/support-reports/00000000-0000-0000-0000-000000000000/priority', {}],
  ['POST', '/support-reports/00000000-0000-0000-0000-000000000000/priority', {}],
  ['POST', '/support-reports/00000000-0000-0000-0000-000000000000/reply', {}],
  ['POST', '/support-reports/00000000-0000-0000-0000-000000000000/internal-note', {}],
  ['GET', '/notifications'],
  ['POST', '/notifications/00000000-0000-0000-0000-000000000000/read'],
  ['POST', '/notifications/read-all'],
  ['GET', '/organizer/overview'],
  ['GET', '/organizer/events/summaries'],
  ['GET', '/organizer/profile'],
  ['PUT', '/organizer/profile', {}],
];

(async () => {
  const missing = [];
  let ok = 0;
  for (const [method, path, body] of endpoints) {
    const res = await fetch(API + path, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    // 404 bisa berarti (a) route tidak terdaftar -> notFoundMiddleware, atau
    // (b) route ada tetapi resource tidak ditemukan -> controller. Hanya (a)
    // yang merupakan regresi. Middleware memakai pesan `Not Found - <url>`.
    let isMissingRoute = false;
    if (res.status === 404) {
      const text = await res.text();
      isMissingRoute = text.includes('Not Found - ');
    }
    if (isMissingRoute) {
      missing.push(`${method} ${path}`);
      console.log(`MISSING  ${method} ${path} -> route tidak terdaftar`);
    } else {
      ok += 1;
    }
  }
  console.log(`\nTERDAFTAR: ${ok}/${endpoints.length}`);
  console.log(`HILANG   : ${missing.length}`);
  if (missing.length) process.exitCode = 1;
})();
