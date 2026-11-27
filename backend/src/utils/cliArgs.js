/**
 * Pembacaan argumen CLI untuk skrip verifikasi di `scripts/`.
 *
 * Ada dua hal yang harus ditangani bersamaan:
 *
 *  1. Bentuk penulisan argumen. `--to=alamat@domain.com` dan
 *     `--to alamat@domain.com` sama-sama sah, dan pengguna sering menulis
 *     bentuk pertama pada dokumentasi tetapi bentuk kedua saat mengetik.
 *  2. `npm run <skrip> -- <argumen>`. Di PowerShell, `npm` dijalankan lewat
 *     `npm.ps1`; PowerShell memperlakukan `--` sebagai penanda akhir parameter
 *     sehingga token itu DIBUANG sebelum sampai ke npm. npm lalu membaca
 *     `--to=alamat@domain.com` sebagai konfigurasi npm miliknya sendiri dan
 *     TIDAK meneruskannya sebagai argv skrip, tetapi nilainya tetap tersedia
 *     pada environment anak sebagai `npm_config_to`. Tanpa cadangan ini
 *     perintah yang sudah benar tetap terlihat seperti tanpa argumen
 *     ("tidak ada --to") walau `process.argv` kosong.
 *
 * Urutan pembacaan satu opsi: `--nama=nilai`, `--nama nilai`, lalu
 * `npm_config_<nama>`. Argumen eksplisit selalu menang atas environment.
 */

/** Nama variabel environment yang dipakai npm untuk satu opsi CLI. */
const npmConfigKey = (name) => `npm_config_${String(name || '').trim().toLowerCase().replace(/-/g, '_')}`;

/** True bila token berbentuk `--nama` (bukan nilai biasa). */
const isOptionToken = (token) => {
  const value = String(token ?? '').trim();
  return value.startsWith('--') && value.length > 2;
};

/**
 * Urai token argv menjadi opsi bernilai (`Map`) dan flag tanpa nilai (`Set`).
 *
 * - `--to=alamat`   -> options.to   = 'alamat'
 * - `--to alamat`   -> options.to   = 'alamat' (token berikutnya dipakai)
 * - `--as-configured` -> flags berisi 'as-configured'
 *
 * Token yang tidak diawali `--` dan tidak menjadi nilai opsi diabaikan, supaya
 * pemanggilan seperti `npm run x -- y --to=alamat` tetap terbaca.
 *
 * @param {string[]} tokens
 * @returns {{options: Map<string, string>, flags: Set<string>}}
 */
const parseCliArgs = (tokens = []) => {
  const options = new Map();
  const flags = new Set();
  const list = Array.isArray(tokens) ? tokens : [];

  for (let index = 0; index < list.length; index += 1) {
    const token = String(list[index] ?? '').trim();
    if (!isOptionToken(token)) continue;

    const body = token.slice(2);
    const separator = body.indexOf('=');
    if (separator !== -1) {
      const name = body.slice(0, separator).trim();
      if (!name) continue;
      options.set(name, body.slice(separator + 1).trim());
      continue;
    }

    const name = body.trim();
    if (!name) continue;
    const next = list[index + 1];
    if (next !== undefined && !isOptionToken(next)) {
      options.set(name, String(next).trim());
      index += 1;
    } else {
      flags.add(name);
    }
  }

  return { options, flags };
};

/**
 * Nilai opsi dari environment npm (`npm_config_<nama>`), bila ada.
 * `undefined` berarti opsi tidak diberikan sama sekali.
 */
const readNpmConfigValue = (name, env = process.env) => {
  const raw = env ? env[npmConfigKey(name)] : undefined;
  if (raw === undefined || raw === null) return undefined;
  const value = String(raw).trim();
  return value === '' ? undefined : value;
};

/**
 * Pembaca opsi siap pakai untuk sebuah skrip.
 *
 * @param {string[]} [tokens] token argv (default `process.argv.slice(2)`)
 * @param {object} [env] environment (default `process.env`)
 * @returns {{
 *   read: (name: string) => string,
 *   flag: (name: string) => boolean,
 *   source: (name: string) => 'argv'|'npm-config'|'none',
 *   options: Map<string, string>,
 *   flags: Set<string>
 * }}
 */
const createCliOptions = (tokens = process.argv.slice(2), env = process.env) => {
  const { options, flags } = parseCliArgs(tokens);

  const fromArgv = (name) => {
    const value = options.get(name);
    return value === undefined || value === '' ? undefined : value;
  };

  /** Nilai opsi; string kosong berarti tidak diberikan. */
  const read = (name) => fromArgv(name) ?? readNpmConfigValue(name, env) ?? '';

  /** True bila flag ditulis tanpa nilai (`--dry-run`) atau `npm_config_<nama>=true`. */
  const flag = (name) => {
    if (flags.has(name)) return true;
    const value = readNpmConfigValue(name, env);
    return value === 'true' || value === '1';
  };

  /** Asal nilai opsi, dipakai untuk memberi tahu pengguna bila `--` tertelan. */
  const source = (name) => {
    if (fromArgv(name) !== undefined || flags.has(name)) return 'argv';
    if (readNpmConfigValue(name, env) !== undefined) return 'npm-config';
    return 'none';
  };

  return { read, flag, source, options, flags };
};

module.exports = { parseCliArgs, readNpmConfigValue, createCliOptions };
