"""Render template desain tiket (PDF -> PNG) memakai renderer yang sama.

Template PNG di `backend/assets/ticket-templates/` adalah raster dari template
PDF, jadi keduanya tidak dapat berbeda. Jalankan setelah mengubah tata letak:

    cd backend
    node scripts/render-ticket-samples.js      # membuat PDF template
    py tools/export_ticket_templates.py        # memperbarui PNG template

Dependensi hanya untuk tooling: pypdfium2.
"""

import sys
from pathlib import Path

import pypdfium2 as pdfium

BACKEND = Path(__file__).resolve().parents[1]
SAMPLES = BACKEND / "_verify-out" / "ticket-samples"
TEMPLATE_DIR = BACKEND / "assets" / "ticket-templates"

# Template PNG berukuran 2x kanvas (1684x1188 px landscape, 880x1408 px portrait)
# agar Organizer punya ruang cukup saat mendesain.
SCALE = 2


def export(pdf_name: str, png_name: str) -> None:
    source = SAMPLES / pdf_name
    if not source.exists():
        raise SystemExit(f"Template PDF belum ada: {source}")
    document = pdfium.PdfDocument(str(source))
    page = document[0]
    bitmap = page.render(scale=SCALE)
    target = TEMPLATE_DIR / png_name
    bitmap.to_pil().save(target)
    document.close()
    print(f"{png_name}: {bitmap.width}x{bitmap.height} px")


if __name__ == "__main__":
    export("08-template-landscape.pdf", "ticket-template-landscape.png")
    export("08-template-landscape.pdf", "ticket-template.png")
    export("08-template-portrait.pdf", "ticket-template-portrait.png")
    sys.exit(0)
