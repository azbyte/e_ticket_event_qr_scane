/**
 * Renderer gambar tiket (PDFKit) untuk e-tiket.
 *
 * Modul ini HANYA menggambar; seluruh geometri (posisi, ukuran huruf, kotak
 * elemen, QR) berasal dari `ticketDesignLayout` sehingga tidak ada perhitungan
 * posisi kedua yang bisa menyimpang dari editor/pratinjau.
 *
 * Urutan lapisan (layer) sengaja tetap:
 *   1. artwork (gambar unggahan Organizer ATAU desain default sistem),
 *   2. teks informasi (judul, ID tiket, instruksi),
 *   3. alas putih QR + gambar QR.
 * QR digambar terakhir agar tidak pernah tertutup teks; sebaliknya tumpang
 * tindih QR terhadap teks dicegah saat penyimpanan konfigurasi (lihat
 * `ticketDesignLayout.validateLayout`).
 */
const layoutSpec = require('./ticketDesignLayout');
const ticketFonts = require('./ticketFontService');

/** Palet desain default (diukur dari gambar referensi). */
const PALETTE = Object.freeze({ ...layoutSpec.DEFAULT_COLORS, ivory: '#FFFDF8' });

/** Rasio jarak tepi QR ke tepi kotak putih (quiet zone tambahan). */
const QR_BACKING_INSET = 0.074;
const QR_BACKING_RADIUS = 3;

/** Warna teks informasi (hitam netral, kontras di atas panel pink/krem). */
const TEXT_COLOR = PALETTE.text;

/**
 * Gambar artwork default sistem untuk satu orientasi.
 *
 * Landscape mengikuti gambar referensi Canva: panel kiri merah muda bergradasi
 * selebar `panel_split` kanvas, panel kanan krem, garis perforasi putus-putus,
 * lingkaran besar di sudut kanan atas, lingkaran konsentris + titik di kanan
 * tengah, busur besar di bawah, serta ornamen di panel kiri.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{width: number, height: number}} canvas
 * @param {{panel_split: number}} layout
 */
const drawDefaultArtwork = (doc, canvas, layout) => {
  const { width, height } = canvas;
  const split = layout.panel_split;
  const portrait = height > width;
  const panel = portrait ? height * split : width * split;

  if (portrait) {
    // Portrait: header pink di atas, badan krem di bawah.
    const pink = doc.linearGradient(0, 0, width, panel);
    pink.stop(0, PALETTE.leftTop).stop(0.6, PALETTE.leftMid).stop(1, PALETTE.leftBottom);
    doc.rect(0, 0, width, panel).fill(pink);
    doc.rect(0, panel, width, height - panel).fill(PALETTE.right);
    doc.circle(width, 0, 104).fill(PALETTE.leftTop);
    doc.circle(width, 0, 104).lineWidth(1).strokeColor(PALETTE.accentSoft).stroke();
    doc.circle(width * 0.12, height, 150).lineWidth(1.2)
      .strokeColor(PALETTE.accentSoft).stroke();
    return;
  }

  // CATATAN PENTING: `fillColor(color, opacity)`/`strokeColor(color, opacity)`
  // di PDFKit MENYETEL opacity secara PERSISTEN untuk seluruh gambar berikutnya.
  // Karena itu ornamen yang memakai transparansi selalu dibungkus
  // `save()`/`restore()`, dan tidak ada opacity yang dioper sebagai argumen
  // warna. Tanpa ini, teks dan QR Code setelahnya ikut pudar.
  doc.save();

  const pink = doc.linearGradient(0, 0, 0, height);
  pink.stop(0, PALETTE.leftTop).stop(0.55, PALETTE.leftMid).stop(1, PALETTE.leftBottom);
  doc.rect(0, 0, panel, height).fill(pink);

  // Panel kanan: krem polos + ornamen geometris.
  doc.rect(panel, 0, width - panel, height).fill(PALETTE.right);

  // Lingkaran besar di sudut kanan atas (terpotong tepi kanvas). Radius diukur
  // dari referensi: 358 px pada kanvas 2000 px = 150,7 pt.
  doc.circle(width, 0, 150.7).fill(PALETTE.rightDeep);
  doc.circle(width, 0, 150.7).lineWidth(1).strokeColor(PALETTE.accentSoft).stroke();

  // Busur besar di bawah panel kanan: lingkaran berpusat di garis pemisah bawah
  // (522 pt, 591,6 pt) dengan radius 118,5 pt dan 83 pt (diukur dari referensi).
  doc.save();
  doc.strokeOpacity(0.9);
  doc.circle(522, 591.6, 118.5).lineWidth(1.2).strokeColor(PALETTE.accentSoft).stroke();
  doc.circle(522, 591.6, 83).lineWidth(1.1).strokeColor(PALETTE.accentSoft).stroke();
  doc.restore();

  // Ornamen panel kiri: busur konsentris pada sudut kiri bawah (radius 95 / 129
  // / 163 pt) dan cakram merah muda lembut yang menyeberangi garis pemisah.
  doc.save();
  doc.strokeOpacity(0.28);
  for (const radius of [95, 129, 163]) {
    doc.circle(0, height, radius).lineWidth(1.1).strokeColor(PALETTE.accent).stroke();
  }
  doc.restore();

  // Cakram merah muda lembut yang menyeberangi garis pemisah (diukur dari
  // referensi: pusat 464,6 / 588,3 pt, radius 106,3 pt).
  doc.circle(464.6, 588.3, 106.3).fill('#F2D5D1');
  doc.save();
  doc.strokeOpacity(0.9);
  doc.circle(464.6, 588.3, 106.3).lineWidth(1.1).strokeColor(PALETTE.accentSoft).stroke();
  doc.restore();

  // Lingkaran konsentris + deretan titik di kanan tengah (referensi: pusat
  // 529,7 / 404,2 pt; radius 31 / 23 / 15,5 pt; 5 titik jarak 13 pt).
  doc.save();
  doc.strokeOpacity(0.9);
  for (const radius of [31, 23, 15.5]) {
    doc.circle(529.7, 404.2, radius).lineWidth(1).strokeColor(PALETTE.accentSoft).stroke();
  }
  doc.restore();
  doc.save();
  doc.fillOpacity(0.6);
  doc.fillColor(PALETTE.accent);
  for (let index = 0; index < 5; index += 1) {
    doc.circle(529.7 + 50 + index * 13, 404.2, 2).fill();
  }
  doc.restore();

  // Grid titik dekoratif di atas cakram (referensi: 4 baris x 5 kolom, jarak
  // 14,7 pt, mulai 388 / 486 pt).
  doc.save();
  doc.fillOpacity(0.5);
  doc.fillColor(PALETTE.accent);
  for (let row = 0; row < 4; row += 1) {
    for (let col = 0; col < 5; col += 1) {
      doc.circle(388 + col * 14.7, 486 + row * 14.7, 1.8).fill();
    }
  }
  doc.restore();

  // Garis perforasi pemisah panel (kesan tiket sobek).
  doc.save();
  doc.strokeOpacity(0.7);
  doc.dash(4, { space: 6 }).lineWidth(1.2).strokeColor(PALETTE.accent)
    .moveTo(panel, 14).lineTo(panel, height - 14).stroke();
  doc.undash();
  doc.restore();

  doc.restore();
};


/**
 * Gambar satu blok teks pada kotak hasil `resolveLayout`.
 *
 * Setiap baris digambar terpisah pada posisi vertikal yang dihitung dari
 * `LINE_HEIGHT`, sehingga jarak baris pada PDF sama dengan yang dipakai editor
 * saat menghitung kotak elemen.
 *
 * @param {object} doc dokumen PDFKit
 * @param {object} box kotak elemen dari `resolveLayout().boxes`
 * @param {{regular: string, bold: string}} fontNames
 */
const drawTextBox = (doc, box, fontNames) => {
  if (!box || !Array.isArray(box.lines) || box.lines.length === 0) return;
  doc.save();
  // Opacity direset eksplisit: ornamen artwork memakai transparansi dan state
  // grafis PDFKit bersifat global, sehingga teks wajib digambar 100% opaque.
  doc.fillOpacity(1).strokeOpacity(1);
  doc.font(box.bold ? fontNames.bold : fontNames.regular)
    .fontSize(box.font_size)
    .fillColor(TEXT_COLOR);
  box.lines.forEach((line, index) => {
    if (!line) return;
    doc.text(line, box.x, box.y + index * box.font_size * layoutSpec.LINE_HEIGHT, {
      lineBreak: false,
    });
  });
  doc.restore();
};

/**
 * Gambar alas putih + QR Code.
 *
 * Kotak putih mengikuti ukuran elemen QR (bukan QR + padding besar) dan QR
 * digambar dengan margin dalam sehingga quiet zone tetap memenuhi standar
 * pemindaian. `qrcode` sudah menambahkan quiet zone 2 modul di dalam PNG;
 * inset di sini menambah ruang agar QR tidak menempel tepi kotak putih.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{x: number, y: number, size: number}} rect kotak QR (pt)
 * @param {Buffer} qrBuffer PNG QR Code
 */
const drawQrCode = (doc, rect, qrBuffer) => {
  doc.save();
  doc.fillOpacity(1).strokeOpacity(1);
  doc.roundedRect(rect.x, rect.y, rect.size, rect.size, QR_BACKING_RADIUS).fill('#FFFFFF');
  const inset = rect.size * QR_BACKING_INSET;
  const inner = rect.size - inset * 2;
  doc.image(qrBuffer, rect.x + inset, rect.y + inset, { width: inner, height: inner });
  doc.restore();
};

/**
 * Persegi gambar artwork di dalam kanvas (contain-fit, tanpa distorsi).
 * Bila rasio gambar sama dengan rasio kanvas, persegi ini menutup halaman.
 */
const artworkFrame = (imageSize, { width, height }) => {
  const hasImage = imageSize && imageSize.width > 0 && imageSize.height > 0;
  if (!hasImage) return { x: 0, y: 0, width, height };
  const imageRatio = imageSize.width / imageSize.height;
  const pageRatio = width / height;
  if (Math.abs(imageRatio - pageRatio) < 0.005) return { x: 0, y: 0, width, height };
  if (imageRatio > pageRatio) {
    const frameHeight = width / imageRatio;
    return { x: 0, y: (height - frameHeight) / 2, width, height: frameHeight };
  }
  const frameWidth = height * imageRatio;
  return { x: (width - frameWidth) / 2, y: 0, width: frameWidth, height };
};

/**
 * Gambar seluruh tiket (artwork + teks + QR) pada dokumen PDFKit.
 *
 * @param {object} doc dokumen PDFKit
 * @param {object} options
 * @param {{width: number, height: number}} options.canvas ukuran kanvas (pt)
 * @param {object} options.layout konfigurasi tata letak ternormalisasi
 * @param {object} options.resolved hasil `resolveLayout`
 * @param {Buffer|null} [options.artwork] gambar desain unggahan (null = default)
 * @param {{width: number, height: number}|null} [options.artworkSize]
 * @param {Buffer|null} [options.qrBuffer] PNG QR (null = tanpa QR, mis. template)
 * @param {boolean} [options.qrMarker] gambar penanda kotak QR (template)
 * @returns {{qrRect: {x: number, y: number, size: number}}}
 */
const drawTicket = (doc, {
  canvas, layout, resolved, artwork = null, artworkSize = null,
  qrBuffer = null, qrMarker = false, textMarkers = false,
}) => {
  const fontNames = ticketFonts.registerFonts(doc);
  const { width, height } = canvas;

  if (artwork) {
    doc.rect(0, 0, width, height).fill(PALETTE.ivory);
    const frame = artworkFrame(artworkSize, canvas);
    doc.image(artwork, frame.x, frame.y, { width: frame.width, height: frame.height });
  } else {
    drawDefaultArtwork(doc, canvas, layout);
  }

  // Teks digambar sebelum QR: QR tidak boleh menimpa tulisan.
  for (const key of layoutSpec.TEXT_KEYS) {
    const box = resolved.boxes[key];
    if (!box) continue;
    if (textMarkers) {
      // Template desain: penanda kotak, TANPA teks contoh, agar desain yang
      // diunggah Organizer tidak menghasilkan teks ganda pada tiket final.
      doc.save();
      doc.dash(3, { space: 3 }).lineWidth(0.8).strokeColor(PALETTE.accent, 0.8)
        .rect(box.x, box.y, Math.max(box.width, 40), box.height).stroke();
      doc.undash();
      doc.restore();
    } else {
      drawTextBox(doc, box, fontNames);
    }
  }

  const qrRect = resolved.qr;
  if (qrBuffer) {
    drawQrCode(doc, qrRect, qrBuffer);
  } else if (qrMarker) {
    doc.save();
    doc.dash(4, { space: 4 }).lineWidth(1).strokeColor(PALETTE.accent)
      .rect(qrRect.x, qrRect.y, qrRect.size, qrRect.size).stroke();
    doc.undash();
    doc.restore();
  }
  return { qrRect };
};

module.exports = {
  PALETTE,
  TEXT_COLOR,
  QR_BACKING_INSET,
  QR_BACKING_RADIUS,
  drawDefaultArtwork,
  drawTextBox,
  drawQrCode,
  drawTicket,
  artworkFrame,
};
