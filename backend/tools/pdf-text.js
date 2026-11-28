/**
 * Ekstraksi teks dari PDF hasil PDFKit untuk keperluan test.
 *
 * Sejak tiket memakai font Times New Roman yang TERTANAM (subset TTF), teks di
 * dalam content stream ditulis sebagai **glyph id**, bukan kode karakter. Karena
 * itu teks tidak dapat dibaca langsung dari string hex; test harus memakai
 * `ToUnicode` CMap yang ditulis PDFKit untuk setiap font subset.
 *
 * Helper ini:
 *  1. memecah PDF menjadi objek (`N 0 obj ... endobj`),
 *  2. membaca `/Font` pada resources halaman (nama `/F1` -> objek font),
 *  3. mem-parse `ToUnicode` (`beginbfchar` / `beginbfrange`) tiap font,
 *  4. men-dekode setiap string hex pada blok `BT ... ET` memakai font aktif
 *     (`/Fn ... Tf`), lalu menggabungkannya menjadi teks per baris.
 */
const zlib = require('node:zlib');

const inflate = (buffer) => {
  try {
    return zlib.inflateSync(buffer);
  } catch (_error) {
    return buffer;
  }
};

const parseObjects = (raw) => {
  const objects = new Map();
  const re = /(\d+)\s+0\s+obj([\s\S]*?)endobj/g;
  let match;
  while ((match = re.exec(raw)) !== null) {
    objects.set(Number(match[1]), match[2]);
  }
  return objects;
};

/** Isi stream (sudah di-inflate) dari body objek, atau null. */
const streamOf = (body) => {
  if (!body) return null;
  const start = body.indexOf('stream');
  if (start === -1) return null;
  let offset = start + 'stream'.length;
  if (body[offset] === '\r') offset += 1;
  if (body[offset] === '\n') offset += 1;
  const end = body.lastIndexOf('endstream');
  if (end === -1) return null;
  return inflate(Buffer.from(body.slice(offset, end), 'latin1')).toString('latin1');
};

const hexToText = (hex) => {
  let text = '';
  for (let index = 0; index + 4 <= hex.length; index += 4) {
    text += String.fromCharCode(parseInt(hex.slice(index, index + 4), 16));
  }
  return text;
};

/** Peta glyph id -> teks dari CMap `ToUnicode`. */
const parseCMap = (cmap) => {
  const map = new Map();
  for (const block of cmap.matchAll(/beginbfchar([\s\S]*?)endbfchar/g)) {
    for (const pair of block[1].matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/g)) {
      map.set(parseInt(pair[1], 16), hexToText(pair[2]));
    }
  }
  for (const block of cmap.matchAll(/beginbfrange([\s\S]*?)endbfrange/g)) {
    let body = block[1];
    // Bentuk array: `<lo> <hi> [<u1> <u2> ...]` (dipakai PDFKit untuk subset TTF).
    // Bagian ini WAJIB diproses lebih dulu lalu dihapus dari body, karena isi
    // array juga berbentuk deretan `<hex>` yang dapat salah ditafsirkan sebagai
    // bentuk tunggal `<lo> <hi> <dst>`.
    for (const range of body.matchAll(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*\[([^\]]*)\]/g)) {
      const low = parseInt(range[1], 16);
      const targets = [...range[3].matchAll(/<([0-9A-Fa-f]+)>/g)]
        .map((entry) => hexToText(entry[1]));
      targets.forEach((text, offset) => map.set(low + offset, text));
      body = body.replace(range[0], ' ');
    }
    // Bentuk tunggal: `<lo> <hi> <dst>` (destination bertambah per kode).
    for (const range of body.matchAll(
      /<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/g,
    )) {
      const low = parseInt(range[1], 16);
      const high = parseInt(range[2], 16);
      const destination = parseInt(range[3], 16);
      for (let code = low; code <= high; code += 1) {
        map.set(code, String.fromCharCode(destination + (code - low)));
      }
    }
  }
  return map;
};

/** Nama font pada resources halaman -> peta glyph (`/F1` -> Map). */
const fontMaps = (raw, objects) => {
  const maps = new Map();
  // Resources dapat berada di objek terpisah; ambil SEMUA blok /Font agar tidak
  // bergantung pada struktur objek tertentu.
  for (const match of raw.matchAll(/\/Font\s*<<([\s\S]*?)>>/g)) {
    for (const entry of match[1].matchAll(/\/([A-Za-z0-9]+)\s+(\d+)\s+0\s+R/g)) {
      const fontBody = objects.get(Number(entry[2]));
      if (!fontBody) continue;
      const toUnicode = fontBody.match(/\/ToUnicode\s+(\d+)\s+0\s+R/);
      if (!toUnicode) continue;
      const cmap = streamOf(objects.get(Number(toUnicode[1])));
      if (!cmap) continue;
      maps.set(entry[1], parseCMap(cmap));
    }
  }
  return maps;
};

/**
 * Baris teks yang benar-benar dicetak pada halaman pertama PDF.
 *
 * @param {Buffer} buffer PDF
 * @returns {Array<{text: string, x: number, y: number, size: number}>}
 */
const extractPdfLines = (buffer) => {
  const raw = buffer.toString('latin1');
  const objects = parseObjects(raw);
  const maps = fontMaps(raw, objects);
  const lines = [];
  for (const body of objects.values()) {
    const content = streamOf(body);
    if (!content || !content.includes('BT')) continue;
    for (const block of content.matchAll(/BT([\s\S]*?)ET/g)) {
      const fontMatch = block[1].match(/\/([A-Za-z0-9]+)\s+([\d.]+)\s+Tf/);
      const matrixMatch = block[1].match(/1 0 0 1 ([\d.-]+) ([\d.-]+) Tm/);
      if (!fontMatch || !matrixMatch) continue;
      const map = maps.get(fontMatch[1]);
      let text = '';
      for (const hex of block[1].matchAll(/<([0-9A-Fa-f]+)>/g)) {
        const clean = hex[1];
        for (let index = 0; index + 4 <= clean.length; index += 4) {
          const code = parseInt(clean.slice(index, index + 4), 16);
          text += map && map.has(code) ? map.get(code) : '';
        }
      }
      if (text) {
        lines.push({
          text,
          x: Number(matrixMatch[1]),
          y: Number(matrixMatch[2]),
          size: Number(fontMatch[2]),
        });
      }
    }
  }
  return lines;
};

/** Seluruh teks halaman sebagai satu string (dipisah spasi). */
const extractPdfText = (buffer) =>
  extractPdfLines(buffer).map((line) => line.text).join(' ');

module.exports = { extractPdfLines, extractPdfText };
