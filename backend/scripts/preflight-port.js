/**
 * Preflight backend: pastikan port yang akan dipakai benar-benar bebas.
 *
 * Dipakai `npm run dev` (via `predev`). Latar belakang masalah: `npm start`
 * atau `node server.js` yang dihentikan tidak bersih pada Windows kerap
 * meninggalkan proses yatim yang tetap memegang port 5000. Akibatnya
 * `npm run dev` berikutnya selalu gagal (EADDRINUSE) dan — karena nodemon —
 * berhenti dengan pesan "app crashed - waiting for file changes" tanpa
 * menjelaskan penyebabnya.
 *
 * Perilaku:
 * - Port bebas            -> exit 0, lanjut start.
 * - Port dipakai proses   -> cetak PID + perintah menghentikannya, exit 1.
 *   Dengan `--kill` proses pemakai port dihentikan lebih dulu.
 * - Mode `--soft`         -> hanya memberi peringatan (exit 0), dipakai `npm start`
 *   agar perilaku lama tetap terjaga.
 */
const net = require('node:net');
const { execFileSync } = require('node:child_process');

const args = process.argv.slice(2);
const soft = args.includes('--soft');
const kill = args.includes('--kill');
const port = Number(process.env.PORT || 5000);
const host = process.env.HOST || '0.0.0.0';
// Uji pada alamat yang SAMA dengan yang dipakai server. Di Windows, mengikat
// 127.0.0.1 tetap berhasil walau proses lain memegang 0.0.0.0:PORT, sehingga
// probe pada 127.0.0.1 menghasilkan "port bebas" yang salah.
const probeHost = host;

const log = (...parts) => console.log(...parts);

const canBind = () =>
  new Promise((resolve) => {
    const server = net.createServer();
    server.once('error', (error) => resolve({ ok: false, error }));
    server.once('listening', () => server.close(() => resolve({ ok: true })));
    server.listen(port, probeHost);
  });

/** Cari PID yang memegang port (Windows: netstat, POSIX: lsof). */
const findPidOnPort = () => {
  try {
    if (process.platform === 'win32') {
      const out = execFileSync('netstat', ['-ano', '-p', 'TCP'], { encoding: 'utf8' });
      for (const row of out.split(/\r?\n/)) {
        const cells = row.trim().split(/\s+/);
        // Kolom: Proto | Local Address | Foreign Address | State | PID
        if (cells.length < 5) continue;
        if (cells[3] !== 'LISTENING') continue;
        const localPort = cells[1].slice(cells[1].lastIndexOf(':') + 1);
        if (Number(localPort) !== port) continue;
        const pid = Number(cells[4]);
        if (Number.isInteger(pid) && pid > 0) return pid;
      }
      return null;
    }
    const out = execFileSync('lsof', ['-ti', `tcp:${port}`, '-sTCP:LISTEN'], { encoding: 'utf8' });
    const pid = Number(out.split(/\s+/).filter(Boolean)[0]);
    return Number.isInteger(pid) && pid > 0 ? pid : null;
  } catch {
    return null;
  }
};

const describeProcess = (pid) => {
  try {
    if (process.platform === 'win32') {
      const out = execFileSync(
        'powershell',
        ['-NoProfile', '-Command', `(Get-CimInstance Win32_Process -Filter "ProcessId=${pid}").CommandLine`],
        { encoding: 'utf8' },
      );
      return out.trim() || null;
    }
    const out = execFileSync('ps', ['-p', String(pid), '-o', 'command='], { encoding: 'utf8' });
    return out.trim() || null;
  } catch {
    return null;
  }
};

const killProcess = (pid) => {
  try {
    if (process.platform === 'win32') {
      execFileSync('taskkill', ['/PID', String(pid), '/F'], { stdio: 'ignore' });
    } else {
      process.kill(pid, 'SIGKILL');
    }
    return true;
  } catch {
    return false;
  }
};

const stopHint = (pid) =>
  process.platform === 'win32'
    ? `  Stop-Process -Id ${pid} -Force`
    : `  kill -9 ${pid}`;

(async () => {
  const first = await canBind();
  if (first.ok) {
    log(`[preflight] Port ${port} pada ${host} bebas.`);
    process.exit(0);
  }

  if (first.error?.code !== 'EADDRINUSE') {
    log(`[preflight] Tidak dapat menguji port ${port}: ${first.error?.code || first.error?.message}`);
    process.exit(soft ? 0 : 1);
  }

  const pid = findPidOnPort();
  const command = pid ? describeProcess(pid) : null;

  if (kill && pid) {
    log(`[preflight] Menghentikan proses lama pada port ${port} (PID ${pid}).`);
    if (killProcess(pid)) {
      // Beri waktu OS melepas socket sebelum diuji ulang.
      await new Promise((resolve) => setTimeout(resolve, 1200));
      const second = await canBind();
      if (second.ok) {
        log(`[preflight] Port ${port} sekarang bebas.`);
        process.exit(0);
      }
    }
    log(`[preflight] Gagal membebaskan port ${port} secara otomatis.`);
  }

  log('');
  log(`[preflight] Port ${port} pada ${host} sudah dipakai proses lain.`);
  if (pid) {
    log(`[preflight] PID ${pid}${command ? ` — ${command}` : ''}`);
    log('[preflight] Kemungkinan sisa proses backend sebelumnya. Hentikan dengan:');
    log(stopHint(pid));
    log('[preflight] Atau biarkan skrip ini menghentikannya otomatis:');
    log('  npm run dev:reset');
  } else {
    log('[preflight] PID tidak terdeteksi; periksa manual dengan netstat/lsof.');
  }
  log(`[preflight] Atau jalankan di port lain: PORT=${port + 1} npm run dev`);
  log('');

  process.exit(soft ? 0 : 1);
})();
