const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const app = require('./src/app');
const { bootstrapConfiguredAccounts } = require('./src/services/adminBootstrapService');
const emailService = require('./src/services/emailService');
const emailQueue = require('./src/services/emailQueue');

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';

/**
 * Terjemahkan error `listen` menjadi pesan yang dapat ditindaklanjuti.
 *
 * Tanpa ini, EADDRINUSE dan sejenisnya menjadi unhandled `error` event yang
 * mematikan proses dengan stack trace mentah sehingga penyebabnya tidak jelas.
 */
const explainListenError = (error, port, host) => {
  switch (error.code) {
    case 'EADDRINUSE':
      return [
        'Port ' + port + ' pada ' + host + ' sudah dipakai proses lain.',
        'Hentikan proses tersebut, atau jalankan backend pada port lain:',
        '  PORT=5001 npm start        (PowerShell: $env:PORT=5001; npm start)',
        'Melihat proses pemakai port di Windows:',
        '  Get-NetTCPConnection -LocalPort ' + port + ' -State Listen | Select-Object OwningProcess',
        'Di Linux/macOS:',
        '  lsof -i :' + port + '   atau   ss -ltnp | grep ' + port,
      ].join('\n');
    case 'EACCES':
      return [
        'Tidak punya izin mengikat port ' + port + ' pada ' + host + '.',
        'Gunakan port di atas 1024, misalnya: PORT=5001 npm start',
      ].join('\n');
    case 'EADDRNOTAVAIL':
      return [
        'Alamat ' + host + ' tidak tersedia pada mesin ini.',
        'Periksa nilai HOST pada backend/.env (gunakan 0.0.0.0 atau 127.0.0.1).',
      ].join('\n');
    case 'ENOTFOUND':
      return [
        'Host ' + host + ' tidak dapat di-resolve.',
        'Periksa nilai HOST pada backend/.env.',
      ].join('\n');
    default:
      return (error.code || 'UNKNOWN') + ': ' + error.message;
  }
};

/**
 * Bind port dengan percobaan ulang singkat untuk EADDRINUSE.
 *
 * Saat `nodemon` me-restart, proses lama dihentikan lalu proses baru langsung
 * dijalankan. Pada Windows socket lama belum tentu dilepas tepat waktu sehingga
 * bind gagal sesaat. Tanpa percobaan ulang, nodemon melaporkan
 * "app crashed - waiting for file changes" padahal penyebabnya hanya balapan
 * waktu — inilah sumber utama `npm run dev` terasa tidak bisa dijalankan.
 */
const LISTEN_RETRY_ATTEMPTS = 10;
const LISTEN_RETRY_DELAY_MS = 500;

const listenOnce = (port, host) =>
  new Promise((resolve, reject) => {
    const server = app.listen(port, host);
    const onError = (error) => {
      server.removeListener('listening', onListening);
      reject(error);
    };
    const onListening = () => {
      server.removeListener('error', onError);
      resolve(server);
    };
    server.once('error', onError);
    server.once('listening', onListening);
  });

const listenWithRetry = async (port, host) => {
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await listenOnce(port, host);
    } catch (error) {
      const retryable = error.code === 'EADDRINUSE' && attempt < LISTEN_RETRY_ATTEMPTS;
      if (!retryable) throw error;
      console.log(
        `[startup] Port ${port} masih dipakai (percobaan ${attempt}/${LISTEN_RETRY_ATTEMPTS}), ` +
          'menunggu socket lama dilepas...',
      );
      await new Promise((resolve) => setTimeout(resolve, LISTEN_RETRY_DELAY_MS));
    }
  }
};

const startServer = async () => {
  try {
    const result = await bootstrapConfiguredAccounts();
    // Status saja; password/secret tidak pernah dicatat.
    if (!['SKIPPED', 'UNCHANGED'].includes(result.status)) {
      console.log(`Account bootstrap: ${result.status} - ${result.message}`);
    } else {
      console.log(`Account bootstrap: ${result.status}`);
    }
  } catch (error) {
    // Bootstrap bukan syarat hidup server: API tetap dapat melayani alur lain.
    console.error('Account bootstrap failed:', error.message);
  }

  let server;
  try {
    server = await listenWithRetry(PORT, HOST);
  } catch (error) {
    console.error('[GAGAL] Backend gagal dijalankan.');
    console.error(explainListenError(error, PORT, HOST));
    process.exitCode = 1;
    process.exit(1);
  }

  console.log('Server running on http://' + HOST + ':' + PORT);
  console.log('Environment: ' + (process.env.NODE_ENV || 'development'));

  // Status email (tanpa kredensial): jelas apakah tiket dapat dikirim atau
  // hanya tersedia di aplikasi. Tidak ada nilai rahasia yang dicetak.
  const smtp = emailService.smtpStatus();
  console.log(
    'Email e-ticket: mode=' + smtp.mode +
    (smtp.missing.length > 0 ? ' | belum diisi: ' + smtp.missing.join(', ') : '') +
    (smtp.reason ? ' | ' + smtp.reason : ''),
  );
  emailQueue.startRetryWorker();

  // Error setelah server hidup tetap harus terlihat dan memberi exit code.
  server.on('error', (error) => {
    console.error('[GAGAL] Server error:', error.message);
    process.exitCode = 1;
  });

  // Pastikan proses tidak menjadi yatim saat induk (nodemon/npm) berakhir.
  //
  // Di Windows, nodemon tidak selalu berhasil mengirim SIGTERM ke anaknya;
  // akibatnya `node server.js` lama tetap hidup dan memegang port, sehingga
  // restart berikutnya gagal EADDRINUSE. Server ini karena itu mengawasi
  // induknya sendiri: bila stdin ditutup atau induk hilang, ia berhenti.
  const shutdown = (signal) => {
    console.log('[shutdown] Menerima ' + signal + ', menutup server.');
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3000).unref();
  };
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.once('SIGTERM', () => shutdown('SIGTERM'));

  // Induk menutup stdin (terminal/nodemon berhenti) => hentikan server.
  process.stdin.on('end', () => shutdown('stdin induk ditutup'));
  process.stdin.on('close', () => shutdown('stdin induk ditutup'));
  process.stdin.on('error', () => shutdown('stdin induk error'));
  process.stdin.unref?.();

  return server;
};

if (require.main === module) {
  startServer().catch((error) => {
    console.error('Backend gagal start:', error.message);
    process.exit(1);
  });
}

module.exports = app;
module.exports.startServer = startServer;
module.exports.explainListenError = explainListenError;
module.exports.listenWithRetry = listenWithRetry;