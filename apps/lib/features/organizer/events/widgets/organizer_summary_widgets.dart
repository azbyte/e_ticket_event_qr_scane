/// Widget ringkasan untuk tab Ringkasan event dan pratinjau publik.
///
/// Semua angka berasal dari fixture lokal (simulasi) dan tidak mengklaim
/// pendapatan platform, fee, maupun komisi (PRD 7.3).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as core;
import '../../../../services/organizer_events/organizer_event_contract.dart';

/// Utilitas format tampilan untuk layar Event Organizer.
///
/// Ditulis manual (tanpa paket `intl`) agar tidak menambah dependency proyek.
class OrganizerFormatters {
  OrganizerFormatters._();

  /// Format rupiah sederhana, mis. `250000` → `Rp 250.000`.
  static String rupiah(double value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}Rp $buffer';
  }

  /// Format angka ribuan sederhana, mis. `1200` → `1.200`.
  static String thousands(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }
}

/// Satu kotak statistik.
class OrganizerStatTile extends StatelessWidget {
  const OrganizerStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.primaryColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
}

/// Grid statistik responsif: 2 kolom pada layar sempit, 4 kolom pada layar lebar.
class OrganizerStatGrid extends StatelessWidget {
  const OrganizerStatGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 2;
          const spacing = 12.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              for (final tile in tiles)
                SizedBox(width: width, child: tile),
            ],
          );
        },
      );
}

/// Grafik batang sederhana tanpa dependency tambahan (demo).
///
/// Data adalah fixture lokal; label sumbu memakai tanggal singkat.
class OrganizerMiniBarChart extends StatelessWidget {
  const OrganizerMiniBarChart({
    super.key,
    required this.series,
    this.barColor = AppTheme.primaryColor,
    this.height = 120,
    this.emptyMessage = 'Belum ada data grafik untuk event ini.',
  });

  final List<OrganizerEventSalesPoint> series;
  final Color barColor;
  final double height;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final maxValue = series
        .map((point) => point.tickets)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final point in series)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${point.tickets}',
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: maxValue == 0
                            ? 0.02
                            : (point.tickets / maxValue).clamp(0.02, 1.0),
                        widthFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor.withValues(alpha: 0.75),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      core.DateUtils.formatDate(point.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder QR registrasi berbasis pola deterministik dari [seed].
///
/// Ini BUKAN QR yang dapat dipindai; hanya representasi visual prototipe.
/// Tautan asli tetap ditampilkan sebagai teks agar dapat disalin.
class OrganizerQrPlaceholder extends StatelessWidget {
  const OrganizerQrPlaceholder({
    super.key,
    required this.seed,
    this.size = 112,
  });

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _QrPatternPainter(seed: seed),
      );
}

class _QrPatternPainter extends CustomPainter {
  _QrPatternPainter({required this.seed});

  final String seed;

  static const int _modules = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final module = size.width / _modules;
    final hash = seed.codeUnits.fold<int>(7, (acc, unit) => acc * 31 + unit);

    for (var row = 0; row < _modules; row++) {
      for (var col = 0; col < _modules; col++) {
        final isFinder = (row < 3 && col < 3) ||
            (row < 3 && col > _modules - 4) ||
            (row > _modules - 4 && col < 3);
        final bit = (hash >> ((row * _modules + col) % 24)) & 1;
        if (isFinder || bit == 1) {
          canvas.drawRect(
            Rect.fromLTWH(col * module, row * module, module, module),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPatternPainter oldDelegate) => oldDelegate.seed != seed;
}

