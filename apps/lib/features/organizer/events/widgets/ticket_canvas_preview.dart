/// Pratinjau kanvas tiket untuk editor desain (PRD §5).
///
/// Pratinjau menggambar elemen dengan geometri yang SAMA dengan renderer PDF
/// backend (`backend/src/services/ticketPdfRenderer.js`): artwork default
/// (panel pink + krem + ornamen) memakai palet & koordinat yang diukur dari
/// gambar referensi, teks memakai Times New Roman pada ukuran pt kanvas, dan
/// QR Code digambar pada kotak hasil `TicketLayoutModel.resolve()`.
///
/// Setiap elemen memiliki bounding box yang terlihat dan dapat digeser
/// langsung pada kanvas, sehingga Organizer melihat perubahan posisi secara
/// nyata (tidak ada penyesuaian posisi diam-diam).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/event/ticket_design_model.dart';

/// Palet desain default (sama dengan backend `DEFAULT_COLORS`).
class TicketPalette {
  const TicketPalette._();

  static const Color leftTop = Color(0xFFF8E0DC);
  static const Color leftMid = Color(0xFFEDC3BE);
  static const Color leftBottom = Color(0xFFDEA5A0);
  static const Color right = Color(0xFFFBF2E4);
  static const Color rightDeep = Color(0xFFF3E4CD);
  static const Color accent = Color(0xFFC9837F);
  static const Color accentSoft = Color(0xFFE4C3B9);
  static const Color text = Color(0xFF1A1A1A);
  static const Color qrBacking = Color(0xFFFFFFFF);
}

/// Widget pratinjau kanvas tiket (interaktif: elemen dapat digeser).
class TicketCanvasPreview extends StatelessWidget {
  const TicketCanvasPreview({
    super.key,
    required this.orientation,
    required this.layout,
    required this.eventTitle,
    this.imageUrl,
    this.selectedKey,
    this.onSelected,
    this.onLayoutChanged,
    this.interactive = true,
  });

  final TicketOrientation orientation;
  final TicketLayoutModel layout;
  final String eventTitle;
  final String? imageUrl;
  final String? selectedKey;
  final ValueChanged<String?>? onSelected;
  final ValueChanged<TicketLayoutModel>? onLayoutChanged;
  final bool interactive;

  TicketPreviewTexts get _texts => TicketPreviewTexts.forEvent(eventTitle);

  @override
  Widget build(BuildContext context) {
    final canvas = TicketCanvas.forOrientation(orientation);
    final resolved = layout.resolve(orientation: orientation, texts: _texts);
    return AspectRatio(
      aspectRatio: canvas.ratio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / canvas.width;
          final conflictKeys = <String>{
            for (final conflict in resolved.conflicts) ...<String>[
              conflict.a,
              conflict.b,
            ],
          };
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: interactive
                  ? (details) => onSelected?.call(
                      _hitTest(details.localPosition, resolved, scale),
                    )
                  : null,
              onPanStart: interactive
                  ? (details) => onSelected?.call(
                      _hitTest(details.localPosition, resolved, scale),
                    )
                  : null,
              onPanUpdate: interactive
                  ? (details) => _handlePanUpdate(
                      this,
                      details.delta,
                      resolved,
                      scale,
                    )
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: TicketBackgroundPainter(
                      canvas: canvas,
                      layout: layout,
                    ),
                  ),
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Image.network(
                      imageUrl!,
                      key: const Key('ticket-design-preview'),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  CustomPaint(
                    painter: TicketOverlayPainter(
                      canvas: canvas,
                      layout: layout,
                      resolved: resolved,
                      selectedKey: selectedKey,
                      conflictKeys: conflictKeys,
                    ),
                  ),
                  if (resolved.outOfCanvas.isNotEmpty)
                    const Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: CanvasWarning(
                        message: 'Ada elemen di luar kanvas tiket.',
                      ),
                    ),
                ],

              ),
            ),
          );
        },
      ),
    );
  }
}

/// Perbarui posisi elemen yang dipilih saat kanvas digeser.
///
/// Delta layar dikonversi ke fraksi kanvas memakai skala pratinjau, sehingga
/// posisi yang terlihat di editor sama dengan yang disimpan (fraksi 0..1) dan
/// dipakai PDF. Nilai selalu di-clamp agar elemen tidak keluar kanvas.
void _handlePanUpdate(
  TicketCanvasPreview preview,
  Offset delta,
  TicketLayoutResolution resolved,
  double scale,
) {
  final key = preview.selectedKey;
  final onChanged = preview.onLayoutChanged;
  if (key == null || onChanged == null) return;
  final layout = preview.layout;
  final canvas = resolved.canvas;
  final dx = delta.dx / scale / canvas.width;
  final dy = delta.dy / scale / canvas.height;
  if (key == TicketElementKey.qr) {
    final qr = layout.qr;
    onChanged(
      layout.copyWith(
        qr: qr
            .copyWith(
              x: (qr.x + dx).clamp(0, TicketQrPlacement.maxPosition),
              y: (qr.y + dy).clamp(0, TicketQrPlacement.maxPosition),
            )
            .clamped(),
      ),
    );
    return;
  }
  final element = layout.element(key);
  onChanged(
    layout.withElement(
      key,
      element
          .copyWith(
            x: (element.x + dx).clamp(0, TicketLayoutLimits.maxPositionInput),
            y: (element.y + dy).clamp(0, TicketLayoutLimits.maxPositionInput),
          )
          .clamped(),
    ),
  );
}

/// Elemen mana yang berada di bawah titik sentuh (kotak QR diutamakan).
String? _hitTest(
  Offset position,
  TicketLayoutResolution resolved,
  double scale,
) {
  final point = Offset(position.dx / scale, position.dy / scale);
  if (resolved.qr.inflate(4).contains(point)) return TicketElementKey.qr;
  for (final key in TicketElementKey.texts) {
    final box = resolved.box(key);
    if (box != null && box.rect.inflate(4).contains(point)) return key;
  }
  return null;
}

/// Peringatan singkat di atas kanvas pratinjau.
class CanvasWarning extends StatelessWidget {
  const CanvasWarning({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.errorColor.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

/// Artwork default sistem: panel pink bergradasi + panel krem + ornamen.
///
/// Koordinat mengikuti renderer PDF (pt kanvas) agar pratinjau dan hasil PDF
/// memperlihatkan komposisi yang sama. Untuk orientasi portrait, header pink
/// berada di atas (bukan panel kiri).
class TicketBackgroundPainter extends CustomPainter {
  TicketBackgroundPainter({required this.canvas, required this.layout});

  final TicketCanvas canvas;
  final TicketLayoutModel layout;

  @override
  void paint(Canvas paintCanvas, Size size) {
    final scale = size.width / canvas.width;
    paintCanvas.save();
    paintCanvas.scale(scale, scale);
    final portrait = canvas.height > canvas.width;
    final panel = portrait
        ? canvas.height * layout.panelSplit
        : canvas.width * layout.panelSplit;
    final gradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          TicketPalette.leftTop,
          TicketPalette.leftMid,
          TicketPalette.leftBottom,
        ],
        stops: <double>[0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, panel, canvas.height));

    if (portrait) {
      paintCanvas.drawRect(Rect.fromLTWH(0, 0, canvas.width, panel), gradient);
      paintCanvas.drawRect(
        Rect.fromLTWH(0, panel, canvas.width, canvas.height - panel),
        Paint()..color = TicketPalette.right,
      );
      _strokeCircle(
        paintCanvas,
        Offset(canvas.width, 0),
        104,
        TicketPalette.accentSoft,
        1,
      );
      _strokeCircle(
        paintCanvas,
        Offset(canvas.width * 0.12, canvas.height),
        150,
        TicketPalette.accentSoft,
        1.2,
      );
      paintCanvas.restore();
      return;
    }

    paintCanvas.drawRect(Rect.fromLTWH(0, 0, panel, canvas.height), gradient);
    paintCanvas.drawRect(
      Rect.fromLTWH(panel, 0, canvas.width - panel, canvas.height),
      Paint()..color = TicketPalette.right,
    );

    // Lingkaran besar sudut kanan atas.
    paintCanvas.drawCircle(
      Offset(canvas.width, 0),
      150.7,
      Paint()..color = TicketPalette.rightDeep,
    );
    _strokeCircle(
      paintCanvas,
      Offset(canvas.width, 0),
      150.7,
      TicketPalette.accentSoft,
      1,
    );

    // Busur bawah (pusat di garis pemisah bawah).
    _strokeCircle(
      paintCanvas,
      const Offset(522, 591.6),
      118.5,
      TicketPalette.accentSoft,
      1.2,
    );
    _strokeCircle(
      paintCanvas,
      const Offset(522, 591.6),
      83,
      TicketPalette.accentSoft,
      1.1,
    );

    // Busur konsentris sudut kiri bawah.
    for (final radius in <double>[95, 129, 163]) {
      _strokeCircle(
        paintCanvas,
        Offset(0, canvas.height),
        radius,
        TicketPalette.accent.withValues(alpha: 0.3),
        1.1,
      );
    }

    // Cakram lembut yang menyeberangi garis pemisah.
    paintCanvas.drawCircle(
      const Offset(464.6, 588.3),
      106.3,
      Paint()..color = const Color(0xFFF2D5D1),
    );
    _strokeCircle(
      paintCanvas,
      const Offset(464.6, 588.3),
      106.3,
      TicketPalette.accentSoft,
      1.1,
    );

    // Lingkaran konsentris + deretan titik.
    for (final radius in <double>[31, 23, 15.5]) {
      _strokeCircle(
        paintCanvas,
        const Offset(529.7, 404.2),
        radius,
        TicketPalette.accentSoft,
        1,
      );
    }
    final dotPaint = Paint()
      ..color = TicketPalette.accent.withValues(alpha: 0.6);
    for (var index = 0; index < 5; index += 1) {
      paintCanvas.drawCircle(
        Offset(529.7 + 50 + index * 13, 404.2),
        2,
        dotPaint,
      );
    }

    // Grid titik di atas cakram.
    final gridPaint = Paint()
      ..color = TicketPalette.accent.withValues(alpha: 0.5);
    for (var row = 0; row < 4; row += 1) {
      for (var col = 0; col < 5; col += 1) {
        paintCanvas.drawCircle(
          Offset(388 + col * 14.7, 486 + row * 14.7),
          1.8,
          gridPaint,
        );
      }
    }

    // Garis perforasi pemisah panel.
    _drawDashedLine(
      paintCanvas,
      Offset(panel, 14),
      Offset(panel, canvas.height - 14),
      Paint()
        ..color = TicketPalette.accent.withValues(alpha: 0.7)
        ..strokeWidth = 1.2,
    );

    paintCanvas.restore();
  }

  static void _strokeCircle(
    Canvas paintCanvas,
    Offset center,
    double radius,
    Color color,
    double width,
  ) {
    paintCanvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width,
    );
  }

  static void _drawDashedLine(
    Canvas paintCanvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dash = 4.0;
    const space = 6.0;
    final total = (end.dy - start.dy).abs();
    var offset = 0.0;
    while (offset < total) {
      final next = math.min(offset + dash, total);
      paintCanvas.drawLine(
        Offset(start.dx, start.dy + offset),
        Offset(end.dx, start.dy + next),
        paint,
      );
      offset = next + space;
    }
  }

  @override
  bool shouldRepaint(TicketBackgroundPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.canvas != canvas;
}


/// Overlay teks, QR Code, dan bounding box elemen.
///
/// Teks digambar dengan Times New Roman pada ukuran pt hasil `resolve()`
/// (ukuran yang sama dengan PDF), lalu kotak elemen ditandai:
///  - abu-abu tipis: bounding box elemen,
///  - biru: elemen terpilih,
///  - merah: elemen yang bertabrakan (QR menutupi tulisan atau teks saling
///    bertumpuk).
class TicketOverlayPainter extends CustomPainter {
  TicketOverlayPainter({
    required this.canvas,
    required this.layout,
    required this.resolved,
    this.selectedKey,
    this.conflictKeys = const <String>{},
  });

  final TicketCanvas canvas;
  final TicketLayoutModel layout;
  final TicketLayoutResolution resolved;
  final String? selectedKey;
  final Set<String> conflictKeys;

  @override
  void paint(Canvas paintCanvas, Size size) {
    final scale = size.width / canvas.width;
    paintCanvas.save();
    paintCanvas.scale(scale, scale);

    for (final key in TicketElementKey.texts) {
      final box = resolved.box(key);
      if (box != null) _drawLines(paintCanvas, box);
    }
    _drawQr(paintCanvas, resolved.qr);

    for (final key in TicketElementKey.texts) {
      final box = resolved.box(key);
      if (box != null) _drawBox(paintCanvas, key, box.rect);
    }
    _drawBox(paintCanvas, TicketElementKey.qr, resolved.qr);

    paintCanvas.restore();
  }

  void _drawLines(Canvas paintCanvas, TicketElementBox box) {
    for (var index = 0; index < box.lines.length; index += 1) {
      final painter = TextPainter(
        text: TextSpan(
          text: box.lines[index],
          style: TextStyle(
            fontFamily: TicketLayoutModel.fontFamily,
            fontSize: box.fontSize,
            fontWeight: box.bold ? FontWeight.bold : FontWeight.normal,
            color: TicketPalette.text,
            height: TicketLayoutLimits.lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        paintCanvas,
        Offset(
          box.left,
          box.top + index * box.fontSize * TicketLayoutLimits.lineHeight,
        ),
      );
      painter.dispose();
    }
  }

  /// Placeholder QR: pola kotak deterministik agar proporsi & posisi terlihat.
  void _drawQr(Canvas paintCanvas, Rect rect) {
    paintCanvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = TicketPalette.qrBacking,
    );
    final inset = rect.width * 0.074;
    final inner = rect.deflate(inset);
    final module = inner.width / 21;
    final dark = Paint()..color = const Color(0xFF111111);
    const pattern = <int>[
      0x1F, 0x11, 0x15, 0x11, 0x1F, 0x00, 0x0A, 0x1F, 0x04, 0x15, 0x1B, 0x11,
      0x0E, 0x11, 0x1F, 0x04, 0x1F, 0x11, 0x15, 0x11, 0x1F,
    ];
    for (var row = 0; row < 21; row += 1) {
      for (var col = 0; col < 21; col += 1) {
        final value = pattern[(row + col * 3) % pattern.length];
        if (((value >> (col % 5)) & 1) != 1) continue;
        paintCanvas.drawRect(
          Rect.fromLTWH(
            inner.left + col * module,
            inner.top + row * module,
            module,
            module,
          ),
          dark,
        );
      }
    }
    // Tiga finder pattern di sudut agar terbaca sebagai QR Code.
    for (final corner in <Offset>[
      Offset(inner.left, inner.top),
      Offset(inner.right - module * 7, inner.top),
      Offset(inner.left, inner.bottom - module * 7),
    ]) {
      final outer = Rect.fromLTWH(corner.dx, corner.dy, module * 7, module * 7);
      paintCanvas.drawRect(outer, Paint()..color = const Color(0xFF111111));
      paintCanvas.drawRect(
        outer.deflate(module),
        Paint()..color = TicketPalette.qrBacking,
      );
      paintCanvas.drawRect(
        outer.deflate(module * 2),
        Paint()..color = const Color(0xFF111111),
      );
    }
  }

  void _drawBox(Canvas paintCanvas, String key, Rect rect) {
    final isConflict = conflictKeys.contains(key);
    final isSelected = selectedKey == key;
    final color = isConflict
        ? const Color(0xFFD93025)
        : isSelected
        ? const Color(0xFF1A73E8)
        : const Color(0xFF8A8A8A);
    if (isConflict) {
      paintCanvas.drawRect(
        rect,
        Paint()..color = const Color(0xFFD93025).withValues(alpha: 0.08),
      );
    }
    paintCanvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected || isConflict ? 1.6 : 0.8
        ..color = color.withValues(alpha: isSelected || isConflict ? 1 : 0.55),
    );
  }

  @override
  bool shouldRepaint(TicketOverlayPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selectedKey != selectedKey ||
      oldDelegate.conflictKeys != conflictKeys ||
      oldDelegate.canvas != canvas;
}

