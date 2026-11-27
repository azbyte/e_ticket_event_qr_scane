"""Dekode QR dari PDF e-tiket yang sudah dirender (bukti dapat dipindai).

Merender halaman PDF pada 300 DPI lalu mendekode QR memakai OpenCV, sehingga
terbentuk bukti QR benar-benar terbaca — bukan hanya "terlihat besar".

Dijalankan manual:
    py tools/decode_ticket_qr.py backend/_verify-out/ticket-landscape-default.pdf

Verifikasi isi QR memang token tiket yang benar (bukan sekadar terdekode):
    py tools/decode_ticket_qr.py --expect=<token> file.pdf

OpenCV hanya alat validasi lokal, bukan dependensi aplikasi.
"""

import sys
from pathlib import Path

import cv2
import numpy as np
import pymupdf

DPI = 300


def decode(pdf_path: Path) -> str | None:
    document = pymupdf.open(pdf_path)
    page = document[0]
    scale = DPI / 72
    pixmap = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale))
    image = np.frombuffer(pixmap.samples, dtype=np.uint8)
    image = image.reshape(pixmap.height, pixmap.width, pixmap.n)
    if pixmap.n == 4:
        image = cv2.cvtColor(image, cv2.COLOR_RGBA2BGR)
    else:
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    document.close()

    detector = cv2.QRCodeDetector()
    data, points, _ = detector.detectAndDecode(image)
    if not data:
        # Coba perbesar 2x bila deteksi pertama gagal (mis. QR kecil).
        enlarged = cv2.resize(image, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
        data, points, _ = detector.detectAndDecode(enlarged)
    if data:
        print(f"TERBACA  {pdf_path.name}")
        print(f"  isi QR : {data[:24]}… ({len(data)} karakter)")
        print(f"  lokasi : {'terdeteksi' if points is not None else '-'}")
        return data
    print(f"GAGAL    {pdf_path.name}: QR tidak terdeteksi")
    return None


if __name__ == "__main__":
    args = sys.argv[1:]
    expected = None
    targets = []
    for arg in args:
        if arg.startswith("--expect="):
            expected = arg.split("=", 1)[1]
        else:
            targets.append(arg)
    if not targets:
        print("Sebutkan file PDF yang diperiksa.")
        sys.exit(2)
    failed = 0
    for target in targets:
        data = decode(Path(target))
        if data is None:
            failed += 1
        elif expected is not None and data != expected:
            print(f"  BEDA   isi QR tidak sama dengan token tiket yang diharapkan")
            failed += 1
        elif expected is not None:
            print("  COCOK  isi QR = token tiket yang diharapkan")
    sys.exit(1 if failed else 0)
