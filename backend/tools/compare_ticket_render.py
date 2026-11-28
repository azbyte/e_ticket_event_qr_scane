"""Bandingkan hasil render PDF e-tiket dengan gambar referensi Canva.

Alat validasi manual (bukan bagian aplikasi):

    cd backend
    py tools/compare_ticket_render.py _verify-out/ticket-samples/01-default-landscape.pdf
    py tools/compare_ticket_render.py --all

Untuk setiap PDF, halaman dirender pada lebar yang sama dengan gambar referensi
(2000 px), lalu diukur: posisi/ukuran blok tulisan, kotak putih QR, dan
pembagian panel. Hasil pengukuran dibandingkan dengan nilai referensi dan
disimpan sebagai gambar bersebelahan (`*_side-by-side.png`) untuk pemeriksaan
visual.

Dependensi hanya untuk validasi lokal: pypdfium2, numpy, Pillow.
"""

import sys
from pathlib import Path

import numpy as np
import pypdfium2 as pdfium
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "docs" / "references" / "desain_tiket_referensi.png"
SAMPLES = Path(__file__).resolve().parents[1] / "_verify-out" / "ticket-samples"

# Pengukuran gambar referensi (2000 x 1414 px). Nilai fraksi dihitung terhadap
# lebar/tinggi gambar sehingga dapat dibandingkan dengan hasil render.
REFERENCE_MEASURE = {
    "canvas": (2000, 1414),
    "panel_split": 1116 / 2000,
    "title": {"left": 90 / 2000, "top": 63 / 1414, "right": 1114 / 2000, "bottom": 146 / 1414},
    "ticket_id": {"left": 89 / 2000, "top": 221 / 1414, "right": 842 / 2000, "bottom": 271 / 1414},
    "instruction": {"left": 92 / 2000, "top": 319 / 1414, "right": 1254 / 2000, "bottom": 384 / 1414},
    "qr": {"left": 120 / 2000, "top": 461 / 1414, "right": 717 / 2000, "bottom": 1059 / 1414},
}


def render(pdf_path: Path, target_width: int) -> Image.Image:
    document = pdfium.PdfDocument(str(pdf_path))
    page = document[0]
    width_pt, _height_pt = page.get_size()
    scale = target_width / width_pt
    bitmap = page.render(scale=scale, rotation=0)
    image = bitmap.to_pil().convert("RGB")
    document.close()
    return image


def measure(image: Image.Image) -> dict:
    """Ukur elemen utama tiket pada gambar hasil render."""
    array = np.array(image).astype(int)
    height, width, _ = array.shape
    gray = array.mean(axis=2)
    dark = gray < 110

    # Pembagian panel: transisi warna pertama pada baris 60% tinggi, dimulai
    # dari 40% lebar agar tidak mengenai blok QR/tulisan di panel kiri.
    row = array[int(height * 0.60)]
    split = None
    for x in range(int(width * 0.40), width):
        if abs(int(row[x][0]) - int(row[x - 1][0])) > 14:
            split = x / width
            break

    # Kotak putih QR: baris yang memuat area putih lebar di panel kiri.
    white = gray > 245
    left_limit = int(width * 0.60)
    rows = white[:, :left_limit].sum(axis=1)
    qr_rows = np.where(rows > left_limit * 0.22)[0]
    qr = None
    if len(qr_rows) > 0:
        band = white[qr_rows.min():qr_rows.max() + 1, :left_limit]
        cols = np.where(band.sum(axis=0) > band.shape[0] * 0.5)[0]
        if len(cols) > 0:
            qr = {
                "left": cols.min() / width,
                "top": qr_rows.min() / height,
                "right": (cols.max() + 1) / width,
                "bottom": (qr_rows.max() + 1) / height,
            }

    # Blok teks: kelompok baris gelap di atas kotak QR.
    text_top = 0
    text_bottom = int(height * (qr["top"] - 0.02)) if qr else int(height * 0.35)
    bands = []
    if text_bottom > text_top:
        counts = dark[text_top:text_bottom].sum(axis=1)
        start = None
        for index, count in enumerate(counts):
            if count > 0 and start is None:
                start = index
            elif count == 0 and start is not None:
                if index - start > 3:
                    bands.append((start, index - 1))
                start = None
        if start is not None and len(counts) - start > 3:
            bands.append((start, len(counts) - 1))
    texts = []
    for start, end in bands:
        xs = np.where(dark[text_top + start:text_top + end + 1].sum(axis=0) > 0)[0]
        if len(xs) == 0:
            continue
        block = {
            "left": xs.min() / width,
            "top": (text_top + start) / height,
            "right": (xs.max() + 1) / width,
            "bottom": (text_top + end + 1) / height,
        }
        # Gabungkan baris yang berdekatan (judul 2-3 baris) menjadi satu blok.
        if texts and block["top"] - texts[-1]["bottom"] <= 0.012:
            previous = texts[-1]
            previous["left"] = min(previous["left"], block["left"])
            previous["right"] = max(previous["right"], block["right"])
            previous["bottom"] = block["bottom"]
        else:
            texts.append(block)
    return {"size": (width, height), "panel_split": split, "qr": qr, "texts": texts}


def fmt(value):
    return "-" if value is None else f"{value:.4f}"


def describe(box: dict | None) -> str:
    if box is None:
        return "tidak terdeteksi"
    return (
        f"kiri {fmt(box['left'])} atas {fmt(box['top'])} "
        f"kanan {fmt(box['right'])} bawah {fmt(box['bottom'])}"
    )


def compare(name: str, measured: dict, expected: dict) -> float:
    """Cetak tabel perbandingan satu elemen; kembalikan selisih maksimum."""
    print(f"  {name:<12} {'kiri':>8} {'atas':>8} {'kanan':>8} {'bawah':>8}")
    print(
        f"  {'referensi':<12} {fmt(expected['left']):>8} {fmt(expected['top']):>8}"
        f" {fmt(expected['right']):>8} {fmt(expected['bottom']):>8}"
    )
    if measured is None:
        print(f"  {'render':<12} {'-':>8} {'-':>8} {'-':>8} {'-':>8}   TIDAK TERDETEKSI")
        return 1.0
    print(
        f"  {'render':<12} {fmt(measured['left']):>8} {fmt(measured['top']):>8}"
        f" {fmt(measured['right']):>8} {fmt(measured['bottom']):>8}"
    )
    worst = max(
        abs(measured["left"] - expected["left"]),
        abs(measured["top"] - expected["top"]),
        abs(measured["right"] - expected["right"]),
        abs(measured["bottom"] - expected["bottom"]),
    )
    print(f"  {'selisih':<12} {'':>8} {'':>8} {'':>8} {'':>8}   maks {worst:.4f} "
          f"({worst * 2000:.0f} px @2000)")
    return worst


def side_by_side(rendered: Image.Image, target: Path) -> None:
    reference = Image.open(REFERENCE).convert("RGB")
    height = 700
    ref_small = reference.resize((int(reference.width * height / reference.height), height))
    run_small = rendered.resize((int(rendered.width * height / rendered.height), height))
    canvas = Image.new("RGB", (ref_small.width + run_small.width + 20, height), "white")
    canvas.paste(ref_small, (0, 0))
    canvas.paste(run_small, (ref_small.width + 20, 0))
    canvas.save(target)


def main(argv: list[str]) -> int:
    if not REFERENCE.exists():
        print(f"Gambar referensi tidak ditemukan: {REFERENCE}")
        return 2
    if "--all" in argv:
        targets = sorted(SAMPLES.glob("*.pdf"))
    else:
        targets = [Path(arg) for arg in argv if not arg.startswith("--")]
    if not targets:
        print("Sebutkan file PDF, atau gunakan --all.")
        return 2

    for pdf_path in targets:
        print(f"\n=== {pdf_path.name} ===")
        image = render(pdf_path, REFERENCE_MEASURE["canvas"][0])
        result = measure(image)
        print(f"  kanvas render {result['size'][0]}x{result['size'][1]} px")
        print(f"  panel split  render {fmt(result['panel_split'])} / referensi "
              f"{fmt(REFERENCE_MEASURE['panel_split'])}")
        worst = 0.0
        keys = ["title", "ticket_id", "instruction"]
        if "--compare" in argv:
            # Perbandingan hanya bermakna untuk tiket dengan tata letak default
            # (acuan referensi). Tata letak kustom sengaja berbeda.
            for index, key in enumerate(keys):
                measured = result["texts"][index] if index < len(result["texts"]) else None
                worst = max(worst, compare(key, measured, REFERENCE_MEASURE[key]))
            worst = max(worst, compare("qr", result["qr"], REFERENCE_MEASURE["qr"]))
            verdict = "COCOK" if worst <= 0.012 else "PERIKSA"
            print(f"  -> {verdict} (selisih maksimum {worst * 100:.2f}% kanvas)")
        else:
            for index, key in enumerate(keys):
                measured = result["texts"][index] if index < len(result["texts"]) else None
                print(f"  {key:<12} {describe(measured)}")
            print(f"  {'qr':<12} {describe(result['qr'])}")
        out = pdf_path.with_name(f"{pdf_path.stem}_side-by-side.png")
        side_by_side(image, out)
        print(f"  -> {out.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

