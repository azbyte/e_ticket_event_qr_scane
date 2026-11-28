/// Tata letak desain tiket (PRD §5) — sisi Flutter.
///
/// Modul ini adalah cermin `backend/src/services/ticketDesignLayout.js`:
/// kanvas, batas nilai, nilai default, algoritma pembungkusan teks, dan
/// deteksi tumpang tindih HARUS identik agar pratinjau editor menampilkan
/// posisi yang sama dengan PDF yang diterima peserta.
///
/// ## Sistem koordinat
///
/// Kanvas = ukuran halaman PDF (pt):
///  - landscape 842 x 594 pt (acuan gambar referensi Canva),
///  - portrait  440 x 704 pt.
///
/// Posisi elemen disimpan sebagai fraksi 0..1 kanvas (`x` = fraksi lebar,
/// `y` = fraksi tinggi) dan ukuran huruf dalam pt kanvas. Nilai `y` adalah tepi
/// ATAS baris teks (sama dengan argumen `y` PDFKit/`TextPainter`).
library;

import 'package:flutter/painting.dart';

/// Orientasi kanvas desain tiket (PRD §5).
///
/// Nilai string mengikuti kontrak backend (`landscape` / `portrait`) dan
/// disimpan di kolom `ticket_design_orientation` sehingga tetap ada walau
/// Organizer belum mengunggah file desain.
enum TicketOrientation {
  // Kanvas landscape 842 x 594 pt (rasio ~1.42:1, setara A4 landscape).
  landscape('landscape', 'Landscape (horizontal)', 842 / 594),
  // Kanvas portrait 440 x 704 pt (rasio 1:1.6).
  portrait('portrait', 'Portrait (vertikal)', 440 / 704);

  const TicketOrientation(this.value, this.label, this.widthToHeightRatio);

  /// Nilai yang dikirim ke/diterima dari API.
  final String value;

  /// Label yang ditampilkan pada formulir Organizer.
  final String label;

  /// Rasio lebar:tinggi kanvas; dipakai untuk memvalidasi unggahan.
  final double widthToHeightRatio;

  bool get isPortrait => this == TicketOrientation.portrait;

  static TicketOrientation fromValue(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return TicketOrientation.values.firstWhere(
      (item) => item.value == value,
      orElse: () => TicketOrientation.landscape,
    );
  }
}

/// Ukuran kanvas tiket dalam pt (sama dengan ukuran halaman PDF).
class TicketCanvas {
  const TicketCanvas(this.width, this.height);

  static const TicketCanvas landscape = TicketCanvas(842, 594);
  static const TicketCanvas portrait = TicketCanvas(440, 704);

  final double width;
  final double height;

  double get ratio => width / height;

  static TicketCanvas forOrientation(TicketOrientation orientation) =>
      orientation.isPortrait ? portrait : landscape;
}

/// Batas nilai konfigurasi tata letak (sama dengan backend `LIMITS`).
class TicketLayoutLimits {
  const TicketLayoutLimits._();

  static const double minPosition = 0;
  static const double maxPosition = 0.98;
  static const double maxPositionInput = 0.95;
  static const double minFontSize = 8;
  static const double maxFontSize = 120;
  static const double minQrSize = 0.15;
  static const double maxQrSize = 0.6;
  static const double minPanelSplit = 0.2;
  static const double maxPanelSplit = 0.85;
  static const double minTextWidth = 0.2;
  static const double maxTextWidth = 1;

  /// Jarak aman antar-elemen (pt) saat menilai tumpang tindih.
  static const double elementGap = 3;

  /// Tinggi baris relatif terhadap ukuran huruf (Times: 1,18 x ukuran).
  static const double lineHeight = 1.18;
}

/// Satu elemen teks pada kanvas tiket (fraksi kanvas + ukuran huruf pt).
class TicketTextElement {
  const TicketTextElement({
    required this.x,
    required this.y,
    required this.fontSize,
    this.bold = false,
  });

  final double x;
  final double y;
  final double fontSize;
  final bool bold;

  TicketTextElement copyWith({double? x, double? y, double? fontSize, bool? bold}) =>
      TicketTextElement(
        x: x ?? this.x,
        y: y ?? this.y,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
      );

  /// Nilai dijamin berada di dalam batas yang diterima backend.
  TicketTextElement clamped() => TicketTextElement(
    x: x.clamp(TicketLayoutLimits.minPosition, TicketLayoutLimits.maxPosition),
    y: y.clamp(TicketLayoutLimits.minPosition, TicketLayoutLimits.maxPosition),
    fontSize: fontSize.clamp(
      TicketLayoutLimits.minFontSize,
      TicketLayoutLimits.maxFontSize,
    ),
    bold: bold,
  );

  factory TicketTextElement.fromJson(
    Map<String, dynamic> json, {
    required TicketTextElement fallback,
  }) => TicketTextElement(
    x: (json['x'] as num?)?.toDouble() ?? fallback.x,
    y: (json['y'] as num?)?.toDouble() ?? fallback.y,
    fontSize:
        (json['font_size'] as num?)?.toDouble() ?? fallback.fontSize,
    bold: json['bold'] as bool? ?? fallback.bold,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'font_size': fontSize,
    'bold': bold,
  };

  @override
  bool operator ==(Object other) =>
      other is TicketTextElement &&
      other.x == x &&
      other.y == y &&
      other.fontSize == fontSize &&
      other.bold == bold;

  @override
  int get hashCode => Object.hash(x, y, fontSize, bold);

  @override
  String toString() =>
      'TicketTextElement(x: $x, y: $y, fontSize: $fontSize, bold: $bold)';
}


/// Konfigurasi tata letak tiket (satu sumber kebenaran editor & PDF).
///
/// Nilai default landscape diukur dari gambar referensi
/// `docs/references/desain_tiket_referensi.png` (2000x1414 px = 842x594 pt)
/// sehingga PDF hasil render semirip mungkin dengan desain Canva:
///  - judul `E-TIKET [NAMA ACARA]`: Times New Roman Bold 50 pt, x 4,45%,
///    y 2,86% (tepi atas baris teks; tepi atas glyph 4,46%),
///  - `ID TIKET: ...`: Times New Roman 30 pt, x 4,45%, y 14,70%,
///  - instruksi: Times New Roman 30 pt, x 4,45%, y 21,65%,
///  - QR Code: x 5,95%, y 32,60%, sisi 42,31% tinggi kanvas,
///  - pembagian panel: 55,8% lebar kanvas.
class TicketLayoutModel {
  const TicketLayoutModel({
    this.panelSplit = 0.558,
    this.textWidth = 0.6,
    this.title = const TicketTextElement(
      x: 0.0445,
      y: 0.0286,
      fontSize: 50,
      bold: true,
    ),
    this.ticketId = const TicketTextElement(x: 0.0445, y: 0.147, fontSize: 30),
    this.instruction =
        const TicketTextElement(x: 0.0445, y: 0.2165, fontSize: 30),
    this.qr = const TicketQrPlacement(x: 0.0595, y: 0.326, size: 0.4231),
  });

  /// Instruksi penukaran tiket (teks tetap sesuai referensi).
  static const String instructionText =
      'Silahkan tukarkan tiket di meja registrasi';

  /// Font tiket; harus tersedia di perangkat maupun server PDF.
  static const String fontFamily = 'Times New Roman';

  /// Nilai default landscape (sama dengan backend).
  static const TicketLayoutModel defaultLandscape = TicketLayoutModel();

  /// Nilai default portrait (sama dengan backend).
  static const TicketLayoutModel defaultPortrait = TicketLayoutModel(
    panelSplit: 0.38,
    textWidth: 0.86,
    title: TicketTextElement(x: 0.07, y: 0.042, fontSize: 26, bold: true),
    ticketId: TicketTextElement(x: 0.07, y: 0.108, fontSize: 16),
    instruction: TicketTextElement(x: 0.07, y: 0.152, fontSize: 16),
    qr: TicketQrPlacement(x: 0.07, y: 0.46, size: 0.36),
  );

  final double panelSplit;
  final double textWidth;
  final TicketTextElement title;
  final TicketTextElement ticketId;
  final TicketTextElement instruction;
  final TicketQrPlacement qr;

  static TicketLayoutModel defaultsFor(TicketOrientation orientation) =>
      orientation.isPortrait ? defaultPortrait : defaultLandscape;

  TicketTextElement element(String key) {
    switch (key) {
      case TicketElementKey.title:
        return title;
      case TicketElementKey.ticketId:
        return ticketId;
      default:
        return instruction;
    }
  }

  TicketLayoutModel withElement(String key, TicketTextElement value) {
    switch (key) {
      case TicketElementKey.title:
        return copyWith(title: value);
      case TicketElementKey.ticketId:
        return copyWith(ticketId: value);
      default:
        return copyWith(instruction: value);
    }
  }

  TicketLayoutModel copyWith({
    double? panelSplit,
    double? textWidth,
    TicketTextElement? title,
    TicketTextElement? ticketId,
    TicketTextElement? instruction,
    TicketQrPlacement? qr,
  }) => TicketLayoutModel(
    panelSplit: panelSplit ?? this.panelSplit,
    textWidth: textWidth ?? this.textWidth,
    title: title ?? this.title,
    ticketId: ticketId ?? this.ticketId,
    instruction: instruction ?? this.instruction,
    qr: qr ?? this.qr,
  );

  /// Semua nilai dipotong ke batas backend (dipakai saat memuat data lama).
  TicketLayoutModel clamped() => TicketLayoutModel(
    panelSplit: panelSplit.clamp(
      TicketLayoutLimits.minPanelSplit,
      TicketLayoutLimits.maxPanelSplit,
    ),
    textWidth: textWidth.clamp(
      TicketLayoutLimits.minTextWidth,
      TicketLayoutLimits.maxTextWidth,
    ),
    title: title.clamped(),
    ticketId: ticketId.clamped(),
    instruction: instruction.clamped(),
    qr: qr.clamped(),
  );

  factory TicketLayoutModel.fromJson(
    Map<String, dynamic> json, {
    TicketOrientation orientation = TicketOrientation.landscape,
  }) {
    final fallback = defaultsFor(orientation);
    Map<String, dynamic> read(String key) {
      final value = json[key];
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    }

    return TicketLayoutModel(
      panelSplit: (json['panel_split'] as num?)?.toDouble() ?? fallback.panelSplit,
      textWidth: (json['text_width'] as num?)?.toDouble() ?? fallback.textWidth,
      title: TicketTextElement.fromJson(
        read(TicketElementKey.title),
        fallback: fallback.title,
      ),
      ticketId: TicketTextElement.fromJson(
        read(TicketElementKey.ticketId),
        fallback: fallback.ticketId,
      ),
      instruction: TicketTextElement.fromJson(
        read(TicketElementKey.instruction),
        fallback: fallback.instruction,
      ),
      qr: TicketQrPlacement.fromJson(read('qr'), fallback: fallback.qr),
    ).clamped();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'panel_split': panelSplit,
    'text_width': textWidth,
    'title': title.toJson(),
    'ticket_id': ticketId.toJson(),
    'instruction': instruction.toJson(),
    'qr': qr.toJson(),
  };

  /// Hitung kotak (bounding box) seluruh elemen pada kanvas, dalam pt.
  ///
  /// Dipakai editor untuk menggambar kotak elemen, mendeteksi tumpang tindih,
  /// dan memastikan posisi yang disimpan sama dengan yang dicetak PDF.
  TicketLayoutResolution resolve({
    required TicketOrientation orientation,
    required TicketPreviewTexts texts,
  }) {
    final canvas = TicketCanvas.forOrientation(orientation);
    final maxWidth = textWidth * canvas.width;
    final boxes = <String, TicketElementBox>{};
    for (var index = 0; index < TicketElementKey.texts.length; index += 1) {
      final key = TicketElementKey.texts[index];
      final element = this.element(key);
      final left = element.x * canvas.width;
      final top = element.y * canvas.height;
      final nextKey = index + 1 < TicketElementKey.texts.length
          ? TicketElementKey.texts[index + 1]
          : null;
      final limitY = nextKey == null
          ? canvas.height
          : this.element(nextKey).y * canvas.height;
      final maxHeight = (limitY - top - TicketLayoutLimits.elementGap)
          .clamp(element.fontSize * TicketLayoutLimits.lineHeight, canvas.height);
      boxes[key] = fitElement(
        key,
        texts.forKey(key),
        element,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        left: left,
        top: top,
      );
    }
    return TicketLayoutResolution(
      canvas: canvas,
      boxes: boxes,
      qr: Rect.fromLTWH(
        qr.x * canvas.width,
        qr.y * canvas.height,
        qr.size * canvas.height,
        qr.size * canvas.height,
      ),
    );
  }

  /// Pasangan elemen yang bertabrakan (termasuk QR menutupi tulisan).
  static List<TicketLayoutConflict> findConflicts(TicketLayoutResolution resolved) {
    final conflicts = <TicketLayoutConflict>[];
    final qrRect = resolved.qr;
    for (final key in TicketElementKey.texts) {
      final box = resolved.box(key);
      if (box == null) continue;
      if (_overlaps(box.rect, qrRect)) {
        conflicts.add(
          TicketLayoutConflict(
            a: TicketElementKey.qr,
            b: key,
            message:
                'QR Code menutupi ${TicketElementKey.label(key)}. Geser QR atau '
                'perkecil ukurannya.',
          ),
        );
      }
      for (final otherKey in TicketElementKey.texts) {
        if (otherKey.compareTo(key) <= 0) continue;
        final other = resolved.box(otherKey);
        if (other == null) continue;
        if (_overlaps(box.rect, other.rect)) {
          conflicts.add(
            TicketLayoutConflict(
              a: key,
              b: otherKey,
              message:
                  '${TicketElementKey.label(key)} bertabrakan dengan '
                  '${TicketElementKey.label(otherKey)}.',
            ),
          );
        }
      }
    }
    return conflicts;
  }

  /// Elemen yang keluar dari batas kanvas (toleransi 0,5 pt).
  static List<String> findOutOfCanvas(TicketLayoutResolution resolved) {
    const tolerance = 0.5;
    final canvas = resolved.canvas;
    final problems = <String>[];
    void check(String label, Rect rect) {
      if (rect.left < -tolerance ||
          rect.top < -tolerance ||
          rect.right > canvas.width + tolerance ||
          rect.bottom > canvas.height + tolerance) {
        problems.add('$label keluar dari batas kanvas tiket.');
      }
    }

    for (final key in TicketElementKey.texts) {
      final box = resolved.box(key);
      if (box != null) check(box.label, box.rect);
    }
    check(TicketElementKey.label(TicketElementKey.qr), resolved.qr);
    return problems;
  }

  static bool _overlaps(Rect a, Rect b) => a.overlaps(
    b.inflate(TicketLayoutLimits.elementGap / 2),
  );

  @override
  bool operator ==(Object other) =>
      other is TicketLayoutModel &&
      other.panelSplit == panelSplit &&
      other.textWidth == textWidth &&
      other.title == title &&
      other.ticketId == ticketId &&
      other.instruction == instruction &&
      other.qr == qr;

  @override
  int get hashCode =>
      Object.hash(panelSplit, textWidth, title, ticketId, instruction, qr);
}

/// Posisi & ukuran QR pada kanvas (fraksi 0..1).
class TicketQrPlacement {
  const TicketQrPlacement({
    required this.x,
    required this.y,
    required this.size,
  });

  /// Batas yang sama dengan backend (`QR_PLACEMENT_LIMITS`): posisi 0-95%,
  /// ukuran 15%-60% tinggi kanvas.
  static const double minPosition = 0;
  static const double maxPosition = 0.95;
  static const double minSize = TicketLayoutLimits.minQrSize;
  static const double maxSize = TicketLayoutLimits.maxQrSize;

  final double x;
  final double y;
  final double size;

  /// Nilai yang dijamin berada di dalam batas slider/validasi backend.
  TicketQrPlacement clamped() => TicketQrPlacement(
    x: x.clamp(minPosition, maxPosition),
    y: y.clamp(minPosition, maxPosition),
    size: size.clamp(minSize, maxSize),
  );

  TicketQrPlacement copyWith({double? x, double? y, double? size}) =>
      TicketQrPlacement(
        x: x ?? this.x,
        y: y ?? this.y,
        size: size ?? this.size,
      );

  /// Perbandingan nilai: dipakai untuk mendeteksi perubahan pengaturan QR
  /// sebelum disimpan (bukan perbandingan identitas objek).
  @override
  bool operator ==(Object other) =>
      other is TicketQrPlacement &&
      other.x == x &&
      other.y == y &&
      other.size == size;

  @override
  int get hashCode => Object.hash(x, y, size);

  factory TicketQrPlacement.fromJson(
    Map<String, dynamic> json, {
    TicketQrPlacement? fallback,
  }) {
    final base = fallback ?? TicketLayoutModel.defaultLandscape.qr;
    return TicketQrPlacement(
      x: (json['x'] as num?)?.toDouble() ?? base.x,
      y: (json['y'] as num?)?.toDouble() ?? base.y,
      size: (json['size'] as num?)?.toDouble() ?? base.size,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'size': size,
  };

  @override
  String toString() =>
      'TicketQrPlacement(x: $x, y: $y, size: $size)';
}


/// Kunci elemen teks (sama dengan backend `TEXT_KEYS`).
class TicketElementKey {
  const TicketElementKey._();

  static const String title = 'title';
  static const String ticketId = 'ticket_id';
  static const String instruction = 'instruction';
  static const String qr = 'qr';

  static const List<String> texts = <String>[title, ticketId, instruction];

  static String label(String key) {
    switch (key) {
      case title:
        return 'Judul tiket';
      case ticketId:
        return 'ID tiket';
      case instruction:
        return 'Instruksi penukaran';
      case qr:
        return 'QR Code';
      default:
        return key;
    }
  }
}

/// Teks yang dicetak pada tiket (judul & ID berasal dari data peserta/event).
class TicketPreviewTexts {
  const TicketPreviewTexts({
    required this.title,
    required this.ticketId,
    required this.instruction,
  });

  /// Format judul: `E-TIKET [NAMA ACARA]` huruf kapital.
  factory TicketPreviewTexts.forEvent(String eventTitle) => TicketPreviewTexts(
    title: 'E-TIKET ${eventTitle.trim()}'.toUpperCase(),
    ticketId: 'ID TIKET: ETK-0000000',
    instruction: TicketLayoutModel.instructionText,
  );

  final String title;
  final String ticketId;
  final String instruction;

  String forKey(String key) {
    switch (key) {
      case TicketElementKey.title:
        return title;
      case TicketElementKey.ticketId:
        return ticketId;
      default:
        return instruction;
    }
  }
}

/// Kotak (bounding box) satu elemen pada kanvas, dalam pt.
class TicketElementBox {
  const TicketElementBox({
    required this.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.lines,
    required this.fontSize,
    required this.bold,
    required this.truncated,
  });

  final String key;
  final double left;
  final double top;
  final double width;
  final double height;
  final List<String> lines;
  final double fontSize;
  final bool bold;
  final bool truncated;

  double get right => left + width;
  double get bottom => top + height;

  Rect get rect => Rect.fromLTWH(left, top, width, height);

  String get label => TicketElementKey.label(key);
}

/// Tabrakan antar-elemen yang harus ditampilkan di editor.
class TicketLayoutConflict {
  const TicketLayoutConflict({
    required this.a,
    required this.b,
    required this.message,
  });

  final String a;
  final String b;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is TicketLayoutConflict &&
      other.a == a &&
      other.b == b &&
      other.message == message;

  @override
  int get hashCode => Object.hash(a, b, message);

  @override
  String toString() => message;
}

/// Hasil perhitungan kotak seluruh elemen untuk satu konfigurasi tata letak.
class TicketLayoutResolution {
  const TicketLayoutResolution({
    required this.canvas,
    required this.boxes,
    required this.qr,
  });

  final TicketCanvas canvas;
  final Map<String, TicketElementBox> boxes;
  final Rect qr;

  TicketElementBox? box(String key) => boxes[key];

  /// Elemen (termasuk `qr`) yang bertabrakan; dipakai untuk indikator visual
  /// dan untuk menonaktifkan tombol simpan.
  List<TicketLayoutConflict> get conflicts =>
      TicketLayoutModel.findConflicts(this);

  /// Elemen yang keluar dari batas kanvas.
  List<String> get outOfCanvas => TicketLayoutModel.findOutOfCanvas(this);

  bool get isValid => conflicts.isEmpty && outOfCanvas.isEmpty;
}

/// Pengukur lebar teks memakai font & metrik yang sama dengan pratinjau.
///
/// Di editor Flutter pengukuran memakai `TextPainter` dengan font Times New
/// Roman; backend memakai metrik TTF yang sama (lihat `ticketFontService`).
/// Hasilnya dipakai untuk membungkus teks dan mendeteksi tumpang tindih
/// SEBELUM disimpan, sehingga pratinjau dan PDF tidak berbeda.
class TicketTextMeasurer {
  const TicketTextMeasurer._();

  static final Map<String, double> _cache = <String, double>{};

  static double width(String text, {required double fontSize, required bool bold}) {
    final key = '$bold|$fontSize|$text';
    final cached = _cache[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: TicketLayoutModel.fontFamily,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final value = painter.width;
    painter.dispose();
    _cache[key] = value;
    return value;
  }
}

String _truncateLine(String text, double fontSize, bool bold, double maxWidth) {
  if (TicketTextMeasurer.width(text, fontSize: fontSize, bold: bold) <= maxWidth) {
    return text;
  }
  var cut = text;
  while (cut.length > 1 &&
      TicketTextMeasurer.width('$cut…', fontSize: fontSize, bold: bold) > maxWidth) {
    cut = cut.substring(0, cut.length - 1);
  }
  return '${cut.trimRight()}…';
}

/// Sesuaikan ukuran huruf & pembungkusan satu elemen teks.
///
/// Algoritma sama dengan backend `fitTextElement`: ukuran dipertahankan bila
/// teks muat, diturunkan bertahap 0,5 pt hingga batas minimum (judul 35%,
/// elemen lain 60% ukuran asli), lalu dibungkus hingga batas baris (judul 3
/// baris, lainnya 1 baris) sebelum dipotong dengan elipsis.
TicketElementBox fitElement(
  String key,
  String text,
  TicketTextElement element, {
  required double maxWidth,
  required double maxHeight,
  required double left,
  required double top,
}) {
  final isTitle = key == TicketElementKey.title;
  final lineLimit = isTitle ? 3 : 1;
  final minRatio = isTitle ? 0.35 : 0.6;
  final bold = element.bold;
  final minSize = (element.fontSize * minRatio).clamp(
    TicketLayoutLimits.minFontSize,
    TicketLayoutLimits.maxFontSize,
  );

  List<String> wrap(double size) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return <String>[''];
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (TicketTextMeasurer.width(candidate, fontSize: size, bold: bold) <=
          maxWidth) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) {
        lines.add(current);
        current = word;
        continue;
      }
      lines.add(_truncateLine(word, size, bold, maxWidth));
      current = '';
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? <String>[''] : lines;
  }

  double widest(List<String> lines, double size) => lines.fold<double>(
    0,
    (max, line) {
      final value = TicketTextMeasurer.width(line, fontSize: size, bold: bold);
      return value > max ? value : max;
    },
  );

  var size = element.fontSize;
  var lines = wrap(size);
  var height = lines.length * size * TicketLayoutLimits.lineHeight;
  while ((lines.length > lineLimit || height > maxHeight) &&
      size > minSize + 1e-9) {
    size = (size - 0.5).clamp(minSize, element.fontSize);
    lines = wrap(size);
    height = lines.length * size * TicketLayoutLimits.lineHeight;
  }

  var truncated = false;
  if (lines.length > lineLimit || height > maxHeight) {
    final allowed = (maxHeight / (size * TicketLayoutLimits.lineHeight)).floor();
    final limit = allowed < 1 ? 1 : (allowed > lineLimit ? lineLimit : allowed);
    if (lines.length > limit) {
      final kept = lines.take(limit).toList();
      kept[limit - 1] = _truncateLine(
        lines.skip(limit - 1).join(' '),
        size,
        bold,
        maxWidth,
      );
      lines = kept;
      truncated = true;
    }
    height = lines.length * size * TicketLayoutLimits.lineHeight;
  }

  return TicketElementBox(
    key: key,
    left: left,
    top: top,
    width: widest(lines, size),
    height: height,
    lines: lines,
    fontSize: size,
    bold: bold,
    truncated: truncated,
  );
}

/// Area teks informasi tiket (fraksi kanvas) — tampilan ringkas dari
/// [TicketLayoutModel] untuk kompatibilitas pemanggil lama.
class TicketInfoPlacement {
  const TicketInfoPlacement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String color;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'color': color,
  };
}

