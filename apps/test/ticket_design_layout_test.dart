import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/models/event/ticket_design_model.dart';

void main() {
  // Nilai HARUS sama dengan `DEFAULT_LAYOUT_BY_ORIENTATION` di
  // backend/src/services/ticketDesignLayout.js agar pratinjau editor dan PDF
  // memakai posisi yang identik. Nilai ini diukur dari gambar referensi
  // docs/references/desain_tiket_referensi.png (2000x1414 px = 842x594 pt).
  const landscape = TicketCanvas.landscape;
  const portrait = TicketCanvas.portrait;

  group('Default tata letak tiket', () {
    test('kanvas sama dengan ukuran halaman PDF', () {
      expect(landscape.width, 842);
      expect(landscape.height, 594);
      expect(portrait.width, 440);
      expect(portrait.height, 704);
    });

    test('judul 50 pt bold, ID & instruksi 30 pt regular (referensi Canva)', () {
      final layout = TicketLayoutModel.defaultLandscape;
      expect(layout.title.fontSize, 50);
      expect(layout.title.bold, isTrue);
      expect(layout.ticketId.fontSize, 30);
      expect(layout.ticketId.bold, isFalse);
      expect(layout.instruction.fontSize, 30);
      expect(layout.instruction.bold, isFalse);
      // Posisi kiri 4,45% lebar kanvas untuk ketiga elemen.
      for (final element in <TicketTextElement>[
        layout.title,
        layout.ticketId,
        layout.instruction,
      ]) {
        expect(element.x * landscape.width, closeTo(37.5, 0.5));
      }
      // Jarak vertikal: judul di atas, lalu ID, lalu instruksi.
      expect(layout.title.y, lessThan(layout.ticketId.y));
      expect(layout.ticketId.y, lessThan(layout.instruction.y));
    });

    test('QR default di kiri bawah dengan ukuran mengikuti referensi', () {
      final qr = TicketLayoutModel.defaultLandscape.qr;
      final side = qr.size * landscape.height;
      // Sisi QR ± 251 pt (42,3% tinggi kanvas) seperti gambar referensi.
      expect(side, closeTo(251.3, 1));
      expect(qr.x * landscape.width, closeTo(50.1, 0.5));
      expect(qr.y * landscape.height, closeTo(193.6, 0.5));
      // QR berada di dalam panel kiri dan tidak keluar kanvas.
      expect(qr.x * landscape.width + side, lessThan(landscape.width * 0.558));
      expect(qr.y * landscape.height + side, lessThan(landscape.height));
    });

    test('pembagian panel 55,8% lebar kanvas', () {
      expect(TicketLayoutModel.defaultLandscape.panelSplit, closeTo(0.558, 0.001));
    });

    test('default per orientasi dipilih sesuai orientasi desain', () {
      expect(
        TicketLayoutModel.defaultsFor(TicketOrientation.portrait),
        TicketLayoutModel.defaultPortrait,
      );
      expect(
        TicketLayoutModel.defaultsFor(TicketOrientation.landscape),
        TicketLayoutModel.defaultLandscape,
      );
      expect(TicketDesignModel.defaultQrFor(TicketOrientation.landscape),
          TicketDesignModel.defaultQr);
    });

    test('clamped() menjaga nilai di dalam batas backend', () {
      const raw = TicketLayoutModel(
        panelSplit: 0.99,
        textWidth: 2,
        title: TicketTextElement(x: -1, y: 5, fontSize: 500),
        qr: TicketQrPlacement(x: 1.4, y: -0.2, size: 0.9),
      );
      final clamped = raw.clamped();
      expect(clamped.panelSplit, TicketLayoutLimits.maxPanelSplit);
      expect(clamped.textWidth, TicketLayoutLimits.maxTextWidth);
      expect(clamped.title.x, TicketLayoutLimits.minPosition);
      expect(clamped.title.fontSize, TicketLayoutLimits.maxFontSize);
      expect(clamped.qr.x, TicketQrPlacement.maxPosition);
      expect(clamped.qr.size, TicketQrPlacement.maxSize);
      expect(TicketLayoutModel.defaultLandscape.clamped(),
          TicketLayoutModel.defaultLandscape);
    });
  });

  group('Perhitungan kotak elemen (bounding box)', () {
    test('kotak judul, ID, instruksi di kiri atas tanpa tumpang tindih', () {
      final resolved = TicketLayoutModel.defaultLandscape.resolve(
        orientation: TicketOrientation.landscape,
        texts: TicketPreviewTexts.forEvent('Konser'),
      );
      final title = resolved.box(TicketElementKey.title)!;
      final id = resolved.box(TicketElementKey.ticketId)!;
      final instruction = resolved.box(TicketElementKey.instruction)!;

      expect(title.lines, <String>['E-TIKET KONSER']);
      // Ukuran huruf yang DIKONFIGURASI tetap 50/30/30 (spesifikasi produk);
      // pada lingkungan tanpa font Times New Roman pengukuran memakai font
      // fallback sehingga ukuran hasil fit bisa lebih kecil.
      expect(TicketLayoutModel.defaultLandscape.title.fontSize, 50);
      expect(title.fontSize, lessThanOrEqualTo(50));
      expect(id.fontSize, lessThanOrEqualTo(30));
      expect(instruction.fontSize, lessThanOrEqualTo(30));

      expect(resolved.conflicts, isEmpty);
      expect(resolved.outOfCanvas, isEmpty);
      expect(resolved.isValid, isTrue);

      // Kotak teks berakhir sebelum QR dimulai (QR tidak menutupi tulisan).
      expect(instruction.bottom, lessThan(resolved.qr.top));
    });

    test('QR menutupi tulisan terdeteksi sebagai konflik', () {
      final layout = TicketLayoutModel.defaultLandscape.copyWith(
        qr: const TicketQrPlacement(x: 0.05, y: 0.15, size: 0.5),
      );
      final resolved = layout.resolve(
        orientation: TicketOrientation.landscape,
        texts: TicketPreviewTexts.forEvent('Konser'),
      );
      expect(resolved.conflicts, isNotEmpty);
      expect(
        resolved.conflicts.any((conflict) => conflict.a == TicketElementKey.qr),
        isTrue,
      );
      expect(resolved.isValid, isFalse);
    });

    test('elemen di luar kanvas terdeteksi', () {
      final layout = TicketLayoutModel.defaultLandscape.copyWith(
        instruction: const TicketTextElement(x: 0.9, y: 0.2, fontSize: 30),
      );
      final resolved = layout.resolve(
        orientation: TicketOrientation.landscape,
        texts: TicketPreviewTexts.forEvent('Konser'),
      );
      expect(resolved.outOfCanvas, isNotEmpty);
      expect(resolved.isValid, isFalse);
    });

    test('nama acara panjang dibungkus tanpa keluar dari area teks', () {
      final resolved = TicketLayoutModel.defaultLandscape.resolve(
        orientation: TicketOrientation.landscape,
        texts: TicketPreviewTexts.forEvent(
          'Konferensi Nasional Teknologi Informasi dan Sistem Informasi '
          'Kesehatan 2026',
        ),
      );
      final title = resolved.box(TicketElementKey.title)!;
      final id = resolved.box(TicketElementKey.ticketId)!;
      expect(title.lines.length, greaterThan(1), reason: 'judul dibungkus');
      expect(title.fontSize, lessThan(50), reason: 'ukuran diturunkan');
      expect(title.fontSize, greaterThanOrEqualTo(17.5));
      // Kotak judul tidak melewati kotak ID tiket maupun kanvas.
      expect(title.bottom, lessThanOrEqualTo(id.top));
      expect(title.right, lessThanOrEqualTo(landscape.width));
    });

    test('judul memakai nama acara dinamis, bukan teks statis', () {
      final texts = TicketPreviewTexts.forEvent('  Jazz Malam  ');
      expect(texts.title, 'E-TIKET JAZZ MALAM');
      expect(texts.ticketId, startsWith('ID TIKET: '));
      expect(texts.instruction, TicketLayoutModel.instructionText);
    });
  });

  group('Serialisasi tata letak', () {
    test('toJson/fromJson mempertahankan seluruh nilai', () {
      final layout = TicketLayoutModel.defaultLandscape.copyWith(
        title: const TicketTextElement(x: 0.1, y: 0.2, fontSize: 44, bold: true),
        qr: const TicketQrPlacement(x: 0.4, y: 0.5, size: 0.3),
      );
      final restored = TicketLayoutModel.fromJson(
        layout.toJson(),
        orientation: TicketOrientation.landscape,
      );
      expect(restored, layout);
    });

    test('desain lama tanpa layout memakai default orientasi', () {
      final model = TicketDesignModel.fromJson(<String, dynamic>{
        'file_path': '/media/ticket-designs/evt-1/desain.png',
        'orientation': 'portrait',
      });
      expect(model.layout, TicketLayoutModel.defaultPortrait);
      expect(model.hasUploadedFile, isTrue);
    });

    test('konfigurasi tata letak dapat disimpan tanpa berkas gambar', () {
      final model = TicketDesignModel.fromJson(<String, dynamic>{
        'file_path': null,
        'orientation': 'landscape',
        'layout': <String, dynamic>{
          'qr': <String, dynamic>{'x': 0.3, 'y': 0.4, 'size': 0.3},
        },
      });
      expect(model.hasUploadedFile, isFalse);
      expect(model.layout.qr.x, 0.3);
      expect(model.hasCustomLayout, isTrue);
    });
  });
}

