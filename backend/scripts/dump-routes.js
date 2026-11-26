/* eslint-disable no-console */
// Cetak seluruh route yang benar-benar terdaftar di Express (read-only).
// Dipakai untuk membuktikan path API tidak berubah setelah konsolidasi router.
process.env.NODE_ENV = 'test';
require('dotenv').config();

const app = require('../src/app');

const lines = [];
function walk(stack, prefix) {
  for (const layer of stack) {
    if (layer.route) {
      const methods = Object.keys(layer.route.methods)
        .filter((m) => layer.route.methods[m])
        .map((m) => m.toUpperCase())
        .join(',');
      lines.push(`${methods.padEnd(10)} ${prefix}${layer.route.path}`);
    } else if (layer.name === 'router' && layer.handle && layer.handle.stack) {
      const segment = layer.regexp.source
        .replace('^\\/', '/')
        .replace(/\\\/\?\(\?=\\\/\|\$\)/g, '')
        .replace(/\\\//g, '/')
        .replace(/\$\$.*$/, '')
        .replace(/\?\(\?=\\\/\|\$\)/g, '')
        .replace(/\/\?$/, '')
        .replace(/\$$/, '')
        .replace(/\^/, '');
      walk(layer.handle.stack, prefix + (segment === '/' ? '' : segment));
    }
  }
}

walk(app._router.stack, '');
const unique = [...new Set(lines)].sort();
console.log(`TOTAL ROUTE: ${unique.length}\n`);
unique.forEach((l) => console.log(l));
