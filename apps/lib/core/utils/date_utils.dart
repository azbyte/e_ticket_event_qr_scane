/// Shared date/time formatting helpers.
///
/// Minimal implementation without extra packages. If richer locale-aware
/// formatting is needed, add the `intl` package to pubspec.yaml (see report).
class DateUtils {
  DateUtils._();

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Formats a DateTime to Indonesian short string (e.g. "29 Okt 2026, 19:30").
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    final month = _shortMonths[local.month - 1];
    return '${local.day} $month ${local.year}, ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  /// Formats a DateTime to date-only string (e.g. "29 Okt 2026").
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    final month = _shortMonths[local.month - 1];
    return '${local.day} $month ${local.year}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
