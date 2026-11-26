/**
 * Static file server minimal untuk demo web (build/web).
 *
 * Dipakai agar aplikasi hasil `flutter build web` dapat dibuka tanpa
 * `flutter run`, misalnya pada mesin yang port dev-nya sudah terpakai.
 * Penggunaan: `node scripts/serve-web.js [port] [dir]`.
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const port = Number(process.argv[2] || 3100);
// Default: `apps/build/web` relatif terhadap root repository (dua level di atas
// folder `scripts/`). Path argumen mengalahkan default ini.
const root = path.resolve(
  process.argv[3] || path.join(__dirname, '..', 'apps', 'build', 'web'),
);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  let filePath = path.join(root, urlPath === '/' ? 'index.html' : urlPath);

  // Cegah path traversal keluar dari direktori build.
  if (!filePath.startsWith(root)) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    // Fallback SPA: semua route Flutter dilayani index.html.
    filePath = path.join(root, 'index.html');
  }
  const ext = path.extname(filePath).toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Web demo siap di http://127.0.0.1:${port} (root: ${root})`);
});
