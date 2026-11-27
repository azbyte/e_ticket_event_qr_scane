"""Render PDF e-tiket menjadi PNG untuk pemeriksaan visual.

Dipakai hanya saat validasi manual (bukan bagian aplikasi):
    py tools/render_ticket_pdf.py backend/_verify-out
"""

import sys
from pathlib import Path

import pymupdf

OUT_DIR = Path(sys.argv[1] if len(sys.argv) > 1 else "backend/_verify-out")
RENDER_DIR = OUT_DIR / "render"
RENDER_DIR.mkdir(parents=True, exist_ok=True)

for pdf_path in sorted(OUT_DIR.glob("*.pdf")):
    document = pymupdf.open(pdf_path)
    page = document[0]
    rect = page.rect
    print(f"{pdf_path.name}: {rect.width:.2f} x {rect.height:.2f} pt")
    # 150 DPI agar detail teks kecil & QR tetap terbaca saat diperiksa.
    pixmap = page.get_pixmap(matrix=pymupdf.Matrix(150 / 72, 150 / 72))
    target = RENDER_DIR / f"{pdf_path.stem}.png"
    pixmap.save(target)
    print(f"  -> {target} ({pixmap.width}x{pixmap.height} px)")
    document.close()
