"""Ukur kualitas QR pada PDF e-tiket (quiet zone, ukuran modul, alas putih).

Membuktikan QR cukup besar dan memiliki quiet zone memadai untuk dipindai,
tanpa perlu kamera. Dijalankan manual:
    py tools/check_qr_scannability.py backend/_verify-out/ticket-landscape-default.pdf

Metode: render halaman, ambil kotak QR (diketahui dari tata letak default), lalu
ukur lebar zona terang di sekeliling pola QR, ukuran modul (piksel per modul),
dan ketebalan alas putih di tiap sisi.

Catatan: `QR_BOX` adalah kotak QR tata letak DEFAULT (sistem). Untuk desain
kustom yang memindahkan QR, sesuaikan koordinat di bawah agar pengukuran tepat;
angka yang dilaporkan untuk desain kustom hanya berlaku bila kotaknya sama.
"""

import sys
from pathlib import Path

import pymupdf

# Kotak QR pada tata letak default (pt) — sama dengan LANDSCAPE_CANVAS /
# PORTRAIT_CANVAS di backend/src/services/ticketDesignService.js.
QR_BOX = {
    "landscape": (56, 284, 220),
    "portrait": (36, 266, 250),
}


def analyze(pdf_path: Path, orientation: str) -> bool:
    document = pymupdf.open(pdf_path)
    page = document[0]
    # Render 300 DPI: 1 pt = 300/72 px.
    scale = 300 / 72
    pixmap = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale))
    qr_x, qr_y, qr_side = QR_BOX[orientation]

    left = int(qr_x * scale)
    top = int(qr_y * scale)
    side = int(qr_side * scale)
    samples = pixmap.samples
    width, height = pixmap.width, pixmap.height
    stride = pixmap.stride
    channels = pixmap.n

    def is_dark(x: int, y: int) -> bool:
        offset = y * stride + x * channels
        r, g, b = samples[offset], samples[offset + 1], samples[offset + 2]
        return (r + g + b) / 3 < 110

    # Ukuran modul: panjang run gelap/terang pertama pada baris tengah pola QR.
    mid_y = top + side // 2
    runs = []
    current = is_dark(left, mid_y)
    length = 0
    for x in range(left, min(left + side, width)):
        dark = is_dark(x, mid_y)
        if dark == current:
            length += 1
        else:
            runs.append(length)
            current = dark
            length = 1
    runs.append(length)
    # Modul terkecil pada baris QR adalah satuan modul (bukan area putih besar).
    module_px = min(run for run in runs if run > 0)

    # Quiet zone: piksel terang di luar kotak QR sampai piksel gelap pertama.
    def quiet(pixels):
        count = 0
        for value in pixels:
            if value:
                break
            count += 1
        return count

    up = quiet(is_dark(left + side // 2, y) for y in range(top - 1, -1, -1))
    down = quiet(is_dark(left + side // 2, y) for y in range(top + side, height))
    left_zone = quiet(is_dark(x, mid_y) for x in range(left - 1, -1, -1))
    right_zone = quiet(is_dark(x, mid_y) for x in range(left + side, width))
    quiet_modules = min(up, down, left_zone, right_zone) / module_px

    # Alas putih QR: ukur luas area PUTIH MURNI di sekitar QR. Harus hanya
    # seukuran QR + quiet zone + margin kecil (bukan kartu/panel besar).
    # Ambang ketat (>=254 di semua kanal) agar mat ivory #FFFDF8 pada desain lama
    # tidak ikut terhitung sebagai alas putih.
    def is_white(x: int, y: int) -> bool:
        offset = y * stride + x * channels
        r, g, b = samples[offset], samples[offset + 1], samples[offset + 2]
        return r >= 254 and g >= 254 and b >= 254

    margin_px = int((quiet_modules + 1) * module_px)
    # Batas pencarian di dalam halaman (indeks negatif akan membungkus ke sisi
    # kanan gambar dan menghasilkan pengukuran palsu).
    x0, x1 = max(0, left - margin_px), min(width - 1, left + side + margin_px)
    y0, y1 = max(0, top - margin_px), min(height - 1, top + side + margin_px)
    white_left = white_right = white_top = white_bottom = 0
    for step in range(1, margin_px * 2):
        if left - step >= x0 and is_white(left - step, mid_y):
            white_left = step
        if left + side + step <= x1 and is_white(left + side + step, mid_y):
            white_right = step
        if top - step >= y0 and is_white(left + side // 2, top - step):
            white_top = step
        if top + side + step <= y1 and is_white(left + side // 2, top + side + step):
            white_bottom = step

    print(f"{pdf_path.name} [{orientation}]")
    print(f"  QR box        : {qr_side:.0f} pt ({qr_side / 72:.2f} inci)")
    module_mm = (module_px / scale) * (25.4 / 72)
    print(f"  Modul         : {module_px:.2f} px @300dpi ({module_mm:.2f} mm per modul)")
    print(f"  Quiet zone    : {quiet_modules:.2f} modul "
          f"(min {min(up, down, left_zone, right_zone)} px)")
    print(f"  Alas putih    : +{white_left / module_px:.2f} / +{white_right / module_px:.2f} / "
          f"+{white_top / module_px:.2f} / +{white_bottom / module_px:.2f} modul "
          f"(kiri/kanan/atas/bawah)")
    document.close()

    # Syarat pemindaian: modul >= 0.4 mm dan quiet zone >= 2 modul.
    module_ok = module_mm >= 0.4
    quiet_ok = quiet_modules >= 2
    # Alas putih hanya boleh berupa margin tipis: <= 6 modul (~15 pt) di tiap sisi.
    backing_ok = max(white_left, white_right, white_top, white_bottom) / module_px <= 6
    print(f"  STATUS        : {'PASS' if module_ok and quiet_ok and backing_ok else 'FAIL'} "
          f"(modul {'OK' if module_ok else 'terlalu kecil'}, "
          f"quiet zone {'OK' if quiet_ok else 'terlalu sempit'}, "
          f"alas putih {'OK' if backing_ok else 'terlalu besar'})")
    return module_ok and quiet_ok and backing_ok


if __name__ == "__main__":
    targets = sys.argv[1:]
    if not targets:
        print("Sebutkan file PDF yang diperiksa.")
        sys.exit(2)
    results = []
    for target in targets:
        path = Path(target)
        orientation = "portrait" if "portrait" in path.name else "landscape"
        results.append(analyze(path, orientation))
    sys.exit(0 if all(results) else 1)
