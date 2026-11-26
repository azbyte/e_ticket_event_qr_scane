/**
 * Launcher `npm run dev`.
 *
 * Masalah yang diselesaikan: `nodemon server.js` yang dijalankan langsung dari
 * npm meninggalkan proses yatim di Windows ketika terminal induk ditutup atau
 * dibunuh paksa. Proses yatim itu terus memegang port 5000 sehingga
 * `npm run dev` berikutnya selalu gagal (EADDRINUSE) dan terlihat seperti
 * "backend tidak dapat dijalankan".
 *
 * Launcher ini:
 * - menjalankan preflight port lebih dulu (gagal cepat dengan pesan jelas),
 * - menjalankan nodemon sebagai anak dan meneruskan SIGINT/SIGTERM,
 * - menghentikan seluruh pohon proses bila induk (terminal/npm) menghilang.
 */
const { spawn, spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.join(__dirname, '..');
const killOnExit = process.argv.includes('--kill-port');
const extraArgs = process.argv.slice(2).filter((arg) => arg !== '--kill-port');

// 1. Preflight: pastikan port bebas (atau bebaskan bila diminta).
const preflight = spawnSync(
  process.execPath,
  [path.join('scripts', 'preflight-port.js'), ...(killOnExit ? ['--kill'] : [])],
  { cwd: root, stdio: 'inherit' },
);
if (preflight.status !== 0) {
  process.exit(preflight.status ?? 1);
}

// 2. Jalankan nodemon sebagai proses anak.
const nodemonBin = path.join(root, 'node_modules', 'nodemon', 'bin', 'nodemon.js');
const child = spawn(process.execPath, [nodemonBin, 'server.js', ...extraArgs], {
  cwd: root,
  stdio: 'inherit',
});

let shuttingDown = false;

/** Hentikan seluruh pohon proses anak (Windows: taskkill /T). */
const killTree = () => {
  if (!child.pid) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
  } else {
    try {
      process.kill(-child.pid, 'SIGKILL');
    } catch {
      try {
        child.kill('SIGKILL');
      } catch {
        /* sudah berhenti */
      }
    }
  }
};

const shutdown = (reason) => {
  if (shuttingDown) return;
  shuttingDown = true;
  if (reason) console.log(`[dev] ${reason}`);
  killTree();
  setTimeout(() => process.exit(0), 500).unref();
};

process.once('SIGINT', () => shutdown('Menerima SIGINT, menghentikan nodemon.'));
process.once('SIGTERM', () => shutdown('Menerima SIGTERM, menghentikan nodemon.'));
process.once('SIGHUP', () => shutdown('Menerima SIGHUP, menghentikan nodemon.'));
// Fallback bila proses berakhir normal.
process.once('exit', () => killTree());

/**
 * Deteksi induk yang menghilang.
 *
 * Pendekatan heartbeat file tidak dipakai: bila launcher menulis heartbeat-nya
 * sendiri, ia tidak akan pernah melihat "heartbeat basi" miliknya sendiri.
 * Deteksi dilakukan dengan memeriksa keberadaan induk (PPID) secara berkala;
 * `process.kill(pid, 0)` cukup andal untuk ini dan tidak butuh spawn proses.
 *
 * stdin juga dipantau: saat dipanggil lewat pipe (npm menjalankan langsung),
 * penutupan stdin menandakan induk berhenti lebih cepat daripada polling.
 */
const PARENT_POLL_MS = 1000;

const watchParent = (onGone) => {
  const parentPid = process.ppid;
  const timer = setInterval(() => {
    try {
      // Sinyal 0 hanya memeriksa keberadaan proses.
      process.kill(parentPid, 0);
    } catch {
      onGone();
    }
  }, PARENT_POLL_MS);
  timer.unref();
};

const onParentGone = () => shutdown('Induk proses berhenti; menghentikan nodemon dan server.');

// a) stdin sebagai indikator (terpicu saat dipanggil lewat pipe).
process.stdin.on('end', onParentGone);
process.stdin.on('close', onParentGone);
process.stdin.on('error', onParentGone);
process.stdin.unref?.();

// b) Polling PPID: menangkap induk yang dibunuh paksa tanpa sinyal.
watchParent(onParentGone);

child.on('exit', (code, signal) => {
  if (shuttingDown) return;
  killTree();
  process.exit(code ?? (signal ? 1 : 0));
});

child.on('error', (error) => {
  console.error('[dev] Gagal menjalankan nodemon:', error.message);
  console.error('[dev] Pastikan dependency terpasang: npm install');
  process.exit(1);
});
