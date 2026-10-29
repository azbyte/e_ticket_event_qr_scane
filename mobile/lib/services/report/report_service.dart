/// Support report service (PRD section 4.10).
///
/// Manages support tickets, user trouble reporting, admin tracking,
/// status transitions, and issue resolution notes.
library;

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/report/support_report_model.dart';
import '../api/api_service.dart';

class ReportService {
  ReportService();

  final ApiService _api = ApiService();

  // In-memory mock database of support reports
  static final List<SupportReportModel> _mockReports = [
    SupportReportModel(
      id: 'rpt-001',
      userId: 'usr-002',
      contactEmail: 'dewi.lestari@example.com',
      orderReference: 'ORD-2026-9901',
      category: 'Pembayaran',
      description: 'Saya sudah mentransfer nominal tiket via QRIS simulasi namun status pembayaran belum berubah menjadi Paid.',
      status: AppConstants.reportStatusInProgress,
      ticketNumber: 'RPT-2026-001',
      statusToken: 'st-token-dewi-9901',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      handledBy: 'Admin Platform',
    ),
    SupportReportModel(
      id: 'rpt-002',
      userId: 'usr-003',
      contactEmail: 'ahmad.fauzi@example.com',
      orderReference: 'ORD-2026-9902',
      category: 'E-Tiket & QR',
      description: 'QR Code di aplikasi tidak bisa dimuat saat berada di lobi acara karena sinyal internet lemah.',
      status: AppConstants.reportStatusResolved,
      ticketNumber: 'RPT-2026-002',
      statusToken: 'st-token-ahmad-9902',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      handledBy: 'Admin Platform',
    ),
    SupportReportModel(
      id: 'rpt-003',
      userId: null,
      contactEmail: 'tamu.event@example.com',
      orderReference: 'ORD-2026-9903',
      category: 'Data Peserta',
      description: 'Ada salah ketik pada penulisan nama peserta sertifikat saat pendaftaran tanpa akun.',
      status: AppConstants.reportStatusOpen,
      ticketNumber: 'RPT-2026-003',
      statusToken: 'st-token-guest-9903',
      createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
  ];

  /// Creates a new support report.
  Future<Map<String, dynamic>> createReport(Map<String, dynamic> payload) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final nextNum = _mockReports.length + 1;
      final ticketNum = 'RPT-2026-00$nextNum';
      final statusToken = 'tok-${DateTime.now().millisecondsSinceEpoch}';

      final newReport = SupportReportModel(
        id: 'rpt-${DateTime.now().millisecondsSinceEpoch}',
        userId: payload['user_id'] as String?,
        contactEmail: payload['contact_email'] as String? ?? 'guest@example.com',
        orderReference: payload['order_reference'] as String? ?? '',
        category: payload['category'] as String? ?? 'Umum',
        description: payload['description'] as String? ?? '',
        status: AppConstants.reportStatusOpen,
        ticketNumber: ticketNum,
        statusToken: statusToken,
        createdAt: DateTime.now(),
      );

      _mockReports.insert(0, newReport);
      return newReport.toJson();
    }

    return _api.post('/support-reports', body: payload);
  }

  /// Lists reports with optional filter.
  Future<List<Map<String, dynamic>>> listReports({
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      var list = List<SupportReportModel>.from(_mockReports);

      final status = query?['status'] as String?;
      if (status != null && status.isNotEmpty && status != 'all') {
        list = list.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
      }

      final category = query?['category'] as String?;
      if (category != null && category.isNotEmpty && category != 'all') {
        list = list.where((r) => r.category.toLowerCase() == category.toLowerCase()).toList();
      }

      return list.map((r) => r.toJson()).toList();
    }

    final result = await _api.get('/support-reports', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Gets single report details by ID or Ticket Number.
  Future<Map<String, dynamic>> getReport(String reportId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final report = _mockReports.firstWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
        orElse: () => _mockReports.first,
      );
      return report.toJson();
    }
    return _api.get('/support-reports/$reportId');
  }

  /// Updates report status and appends admin notes.
  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? note,
    String handledBy = 'Admin Platform',
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final idx = _mockReports.indexWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      );

      if (idx != -1) {
        final existing = _mockReports[idx];
        final updated = SupportReportModel(
          id: existing.id,
          userId: existing.userId,
          contactEmail: existing.contactEmail,
          orderReference: existing.orderReference,
          category: existing.category,
          description: existing.description,
          status: status,
          ticketNumber: existing.ticketNumber,
          statusToken: existing.statusToken,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          handledBy: handledBy,
        );
        _mockReports[idx] = updated;
        return updated.toJson();
      }
      return {'success': false, 'message': 'Report not found'};
    }

    return _api.post('/support-reports/$reportId/status', body: {
      'status': status,
      'note': note,
      'handled_by': handledBy,
    });
  }
}
