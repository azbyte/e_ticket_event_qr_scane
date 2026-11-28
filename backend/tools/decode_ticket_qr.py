"""Dekode QR dari PDF e-tiket yang sudah dirender (bukti dapat dipindai).

Merender halaman PDF pada 300 DPI lalu mendekode QR memakai OpenCV, sehingga
terbentuk bukti QR benar-benar terbaca — bukan hanya "terlihat besar".

Dijalankan manual:

    cd backend
    py tools/decode_ticket_qr.py _verify-out/ticket-samples/01-default-landscape.pdf

Verifikasi isi QR memang token tiket yang benar (bukan sekadar terdekode):

    py tools/decode_ticket_qr.py --expect=<token> file.pdf

Seluruh PDF pada manifest sample dapat diperiksa sekaligus:

    py tools/decode_ticket_qr.py --manifest _verify-out/ticket-samples/manifest.json

Renderer memakai `pypdfium2` (sudah dipakai `export_ticket_templates.py`);
`pymupdf` dipakai sebagai fallback bila tersedia. OpenCV hanya alat validasi
lokal, bukan dependensi aplikasi.
"""

import json
import sys
from pathlib import Path

import cv2
import numpy as np

DPI = 300


def render_rgb(pdf_path: Path) -> np.ndarray:
    """Render halaman pertama PDF menjadi array RGB (numpy)."""
    try:
        import pypdfium2 as pdfium
    except ModuleNotFoundError:  # fallback ke pymupdf bila tersedia
        import pymupdf

        document = pymupdf.open(pdf_path)
        page = document[0]
        scale = DPI / 72
        pixmap = page.get_pixmap(matrix=pymupdf.Matrix(scale, scale))
        image = np.frombuffer(pixmap.samples, dtype=np.uint8)
        image = image.reshape(pixmap.height, pixmap.width, pixmap.n)
        document.close()
        return image[:, :, :3]

    document = pdfium.PdfDocument(str(pdf_path))
    page = document[0]
    bitmap = page.render(scale=DPI / 72)
    image = np.array(bitmap.to_pil().convert("RGB"))
    document.close()
    return image


def decode(pdf_path: Path) -> str | None:
    image = render_rgb(pdf_path)
    detector = cv2.QRCodeDetector()
    data, points, _ = detector.detectAndDecode(cv2.cvtColor(image, cv2.COLOR_RGB2BGR))
    if not data:
        # Coba perbesar 2x bila deteksi pertama gagal (mis. QR kecil).
        enlarged = cv2.resize(image, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
        data, points, _ = detector.detectAndDecode(
            cv2.cvtColor(enlarged, cv2.COLOR_RGB2BGR),
        )
    if data:
        print(f"TERBACA  {pdf_path.name}")
        print(f"  isi QR : {data[:24]}… ({len(data)} karakter)")
        print(f"  lokasi : {'terdeteksi' if points is not None else '-'}")
        return data
    print(f"GAGAL    {pdf_path.name}: QR tidak terdeteksi")
    return None


def main(argv: list[str]) -> int:
    expected = None
    targets: list[Path] = []
    manifest_path = None
    for arg in argv:
        if arg.startswith("--expect="):
            expected = arg.split("=", 1)[1]
        elif arg.startswith("--manifest="):
            manifest_path = Path(arg.split("=", 1)[1])
        else:
            targets.append(Path(arg))

    expected_by_file: dict[str, str] = {}
    if manifest_path is not None:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        base = manifest_path.parent
        for entry in manifest.get("tickets", []):
            targets.append(base / entry["file"])
            expected_by_file[entry["file"]] = entry["token"]

    if not targets:
        print("Sebutkan file PDF, atau gunakan --manifest=<file manifest.json>.")
        return 2

    failed = 0
    for target in targets:
        data = decode(target)
        want = expected if expected is not None else expected_by_file.get(target.name)
        if data is None:
            failed += 1
        elif want is not None and data != want:
            print("  BEDA   isi QR tidak sama dengan token tiket yang diharapkan")
            failed += 1
        elif want is not None:
            print("  COCOK  isi QR = token tiket yang diharapkan")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
