/// Support report service (PRD sections 4.10, 6.8, FR-94 s.d. FR-101).
///
/// Manages support tickets, user trouble reporting, admin tracking,
/// status transitions, priorities, public replies, internal notes,
/// and resolution activities.
library;

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/report/report_activity_model.dart';
import '../../models/report/support_report_model.dart';
import '../api/api_service.dart';

class ReportService {
  ReportService();

  final ApiService _api = ApiService();

  // In-memory mock database of support reports
  static List<SupportReportModel> _mockReports = _initialReports();

  static List<SupportReportModel> _initialReports() => [
        SupportReportModel(
          id: 'rpt-001',
          userId: 'usr-part-002',
          contactEmail: 'dewi.lestari@example.com',
          orderReference: 'ORD-2026-9901',
          category: 'PAYMENT',
          subject: 'Kendala verifikasi pembayaran QRIS tiket festival',
          description:
              'Saya sudah mentransfer nominal tiket via QRIS simulasi namun status pembayaran belum berubah menjadi Paid.',
          status: AppConstants.reportStatusInProgress,
          priority: 'high',
          ticketNumber: 'RPT-2026-001',
          statusToken: 'st-token-dewi-9901',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          handledBy: 'Admin Platform',
          replies: [
            ReportReplyModel(
              id: 'rep-001-1',
              reportId: 'rpt-001',
              senderName: 'Dewi Lestari',
              senderRole: 'Pelapor',
              message:
                  'Bukti transfer QRIS nomor ref 9988221 sudah berhasil terpotong dari saldo.',
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            ),
            ReportReplyModel(
              id: 'rep-001-2',
              reportId: 'rpt-001',
              senderName: 'Admin Platform',
              senderRole: 'Admin Platform',
              message:
                  'Halo Ibu Dewi, tim finance sedang mencocokkan mutasi rekening simulasi. Mohon ditunggu sebentar.',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ],
          internalNotes: [
            ReportInternalNoteModel(
              id: 'not-001-1',
              reportId: 'rpt-001',
              authorName: 'Admin Platform',
              note:
                  'Mutasi bank terkonfirmasi masuk pukul 14:15. Butuh trigger callback order update.',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ],
          activities: [
            ReportActivityModel(
              id: 'act-001-1',
              reportId: 'rpt-001',
              action: 'Laporan Dibuat',
              note: 'Pelapor membuat tiket kendala baru',
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            ),
            ReportActivityModel(
              id: 'act-001-2',
              reportId: 'rpt-001',
              staffName: 'Admin Platform',
              action: 'Status Diubah',
              note: 'Status diubah ke In Progress & balasan terkirim',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ],
        ),
        SupportReportModel(
          id: 'rpt-002',
          userId: 'usr-part-001',
          contactEmail: 'ahmad.fauzi@example.com',
          orderReference: 'ORD-2026-9902',
          category: 'E_TICKET',
          subject: 'QR Code tiket tidak muncul saat offline di lokasi',
          description:
              'QR Code di aplikasi tidak bisa dimuat saat berada di lobi acara karena sinyal internet lemah.',
          status: AppConstants.reportStatusResolved,
          priority: 'medium',
          ticketNumber: 'RPT-2026-002',
          statusToken: 'st-token-ahmad-9902',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
          handledBy: 'Admin Platform',
          replies: [
            ReportReplyModel(
              id: 'rep-002-1',
              reportId: 'rpt-002',
              senderName: 'Admin Platform',
              senderRole: 'Admin Platform',
              message:
                  'Tiket sudah kami kirimkan ulang dalam format PDF cadangan ke email terdaftar.',
              createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            ),
          ],
          internalNotes: [
            ReportInternalNoteModel(
              id: 'not-002-1',
              reportId: 'rpt-002',
              authorName: 'Admin Platform',
              note:
                  'Peserta telah berhasil check-in secara manual di gate 2.',
              createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            ),
          ],
          activities: [
            ReportActivityModel(
              id: 'act-002-1',
              reportId: 'rpt-002',
              action: 'Laporan Dibuat',
              note: 'Laporan diterima sistem',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
            ReportActivityModel(
              id: 'act-002-2',
              reportId: 'rpt-002',
              staffName: 'Admin Platform',
              action: 'Status Diubah',
              note: 'Status diubah ke Resolved',
              createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            ),
          ],
        ),
        SupportReportModel(
          id: 'rpt-003',
          userId: null,
          contactEmail: 'tamu.event@example.com',
          orderReference: 'ORD-2026-9903',
          category: 'REGISTRATION',
          subject: 'Koreksi penulisan nama peserta sertifikat seminar',
          description:
              'Ada salah ketik pada penulisan nama peserta sertifikat saat pendaftaran tanpa akun.',
          status: AppConstants.reportStatusOpen,
          priority: 'low',
          ticketNumber: 'RPT-2026-003',
          statusToken: 'st-token-guest-9903',
          createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
          activities: [
            ReportActivityModel(
              id: 'act-003-1',
              reportId: 'rpt-003',
              action: 'Laporan Dibuat',
              note: 'Laporan dari tamu belum diverifikasi',
              createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
            ),
          ],
        ),
        // Sesuai sinkronisasi dengan Organizer (cmp-001 / RPT-ORG-2026-001)
        SupportReportModel(
          id: 'cmp-001',
          userId: 'org-001',
          contactEmail: 'organizer@techsummit.id',
          orderReference: '',
          category: 'EVENT',
          subject:
              'Permohonan percepatan review event Tech Innovation Summit',
          description:
              'Event kami telah diajukan 2 hari lalu namun status masih pending review. Mohon bantuan konfirmasi dokumen perizinan tempat acara.',
          status: AppConstants.reportStatusInProgress,
          priority: 'urgent',
          ticketNumber: 'RPT-ORG-2026-001',
          statusToken: 'tok-org-alpha-991',
          createdAt: DateTime.now().subtract(const Duration(hours: 24)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
          handledBy: 'Admin Platform',
          replies: [
            ReportReplyModel(
              id: 'rep-cmp1-1',
              reportId: 'cmp-001',
              senderName: 'Penyelenggara',
              senderRole: 'Penyelenggara',
              message:
                  'Halo admin, tiket acara kami sudah mulai dipromosikan, mohon bantuannya untuk peninjauan.',
              createdAt: DateTime.now().subtract(const Duration(hours: 24)),
            ),
            ReportReplyModel(
              id: 'rep-cmp1-2',
              reportId: 'cmp-001',
              senderName: 'Admin Platform',
              senderRole: 'Admin Platform',
              message:
                  'Halo Tim Tech Innovation Summit. Dokumen perizinan Anda sudah kami terima dan sedang diverifikasi oleh tim kurasi acara.',
              createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            ),
          ],
          internalNotes: [
            ReportInternalNoteModel(
              id: 'not-cmp1-1',
              reportId: 'cmp-001',
              authorName: 'Admin Platform',
              note:
                  'Catatan internal: Penyelenggara sudah verified, dokumen venue valid. Sedang menunggu approval lead admin.',
              createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            ),
          ],
          activities: [
            ReportActivityModel(
              id: 'act-cmp1-1',
              reportId: 'cmp-001',
              action: 'Laporan Dibuat',
              note: 'Keluhan diajukan oleh penyelenggara',
              createdAt: DateTime.now().subtract(const Duration(hours: 24)),
            ),
            ReportActivityModel(
              id: 'act-cmp1-2',
              reportId: 'cmp-001',
              staffName: 'Admin Platform',
              action: 'Status Diubah',
              note: 'Status diperbarui menjadi In Progress',
              createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            ),
          ],
        ),
        SupportReportModel(
          id: 'rpt-005',
          userId: 'usr-part-003',
          contactEmail: 'siti.nur@example.com',
          orderReference: 'ORD-2026-9905',
          category: 'SCANNER',
          subject: 'Gagal scan tiket pada pintu masuk VIP',
          description:
              'Staf di pintu masuk menginformasikan tiket sudah expired padahal event baru dimulai.',
          status: AppConstants.reportStatusWaitingForUser,
          priority: 'high',
          ticketNumber: 'RPT-2026-005',
          statusToken: 'st-token-siti-9905',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
          handledBy: 'Admin Platform',
          replies: [
            ReportReplyModel(
              id: 'rep-005-1',
              reportId: 'rpt-005',
              senderName: 'Admin Platform',
              senderRole: 'Admin Platform',
              message:
                  'Mohon kirimkan tangkapan layar e-tiket dan kode gate yang dimasuki.',
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ],
          internalNotes: [
            ReportInternalNoteModel(
              id: 'not-005-1',
              reportId: 'rpt-005',
              authorName: 'Admin Platform',
              note:
                  'Ada sync delay pada scanner gate VIP. Menunggu foto tiket dari user.',
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ],
          activities: [
            ReportActivityModel(
              id: 'act-005-1',
              reportId: 'rpt-005',
              action: 'Laporan Dibuat',
              note: 'Laporan dibuat',
              createdAt: DateTime.now().subtract(const Duration(hours: 8)),
            ),
            ReportActivityModel(
              id: 'act-005-2',
              reportId: 'rpt-005',
              staffName: 'Admin Platform',
              action: 'Status Diubah',
              note: 'Menunggu info tambahan dari pelapor',
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ],
        ),
      ];

  /// Reset data mock (berguna untuk testing).
  static void resetMockData() {
    _mockReports = _initialReports();
  }

  /// Creates a new support report.
  Future<Map<String, dynamic>> createReport(Map<String, dynamic> payload) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final nextNum = _mockReports.length + 1;
      final ticketNum = 'RPT-2026-00$nextNum';
      final statusToken = 'tok-${DateTime.now().millisecondsSinceEpoch}';

      final newReport = SupportReportModel(
        id: 'rpt-${DateTime.now().millisecondsSinceEpoch}',
        userId: payload['user_id'] as String?,
        contactEmail: payload['contact_email'] as String? ?? 'guest@example.com',
        orderReference: payload['order_reference'] as String? ?? '',
        category: payload['category'] as String? ?? 'OTHER',
        subject: payload['subject'] as String? ?? 'Laporan Baru',
        description: payload['description'] as String? ?? '',
        status: AppConstants.reportStatusOpen,
        priority: payload['priority'] as String? ?? 'medium',
        ticketNumber: ticketNum,
        statusToken: statusToken,
        createdAt: DateTime.now(),
        activities: [
          ReportActivityModel(
            id: 'act-${DateTime.now().millisecondsSinceEpoch}',
            reportId: 'rpt-${DateTime.now().millisecondsSinceEpoch}',
            action: 'Laporan Dibuat',
            note: 'Tiket berhasil didaftarkan',
            createdAt: DateTime.now(),
          ),
        ],
      );

      _mockReports.insert(0, newReport);
      return newReport.toJson();
    }

    return _api.post('/support-reports', body: payload);
  }

  /// Lists reports with optional filter (status, category, priority, query keyword).
  Future<List<Map<String, dynamic>>> listReports({
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      var list = List<SupportReportModel>.from(_mockReports);

      final status = query?['status'] as String?;
      if (status != null && status.isNotEmpty && status != 'all') {
        list = list.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
      }

      final category = query?['category'] as String?;
      if (category != null && category.isNotEmpty && category != 'all') {
        list = list.where((r) => r.category.toLowerCase() == category.toLowerCase()).toList();
      }

      final priority = query?['priority'] as String?;
      if (priority != null && priority.isNotEmpty && priority != 'all') {
        list = list.where((r) => r.priority.toLowerCase() == priority.toLowerCase()).toList();
      }

      final search = query?['search'] as String?;
      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        list = list.where((r) {
          return r.ticketNumber.toLowerCase().contains(term) ||
              r.description.toLowerCase().contains(term) ||
              r.subject.toLowerCase().contains(term) ||
              (r.contactEmail?.toLowerCase().contains(term) ?? false) ||
              r.orderReference.toLowerCase().contains(term);
        }).toList();
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final report = _mockReports.firstWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
        orElse: () => _mockReports.first,
      );
      return report.toJson();
    }
    return _api.get('/support-reports/$reportId');
  }

  /// Updates report status and appends admin activity.
  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? note,
    String handledBy = 'Admin Platform',
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final idx = _mockReports.indexWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      );

      if (idx != -1) {
        final existing = _mockReports[idx];
        final now = DateTime.now();

        final newActivity = ReportActivityModel(
          id: 'act-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          staffName: handledBy,
          action: 'Status Diubah',
          note: note ?? 'Status diubah ke $status oleh $handledBy',
          createdAt: now,
        );

        final updated = existing.copyWith(
          status: status,
          updatedAt: now,
          handledBy: handledBy,
          activities: [newActivity, ...existing.activities],
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

  /// Updates report priority (FR-98).
  Future<Map<String, dynamic>> updateReportPriority({
    required String reportId,
    required String priority,
    String handledBy = 'Admin Platform',
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final idx = _mockReports.indexWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      );

      if (idx != -1) {
        final existing = _mockReports[idx];
        final now = DateTime.now();

        final newActivity = ReportActivityModel(
          id: 'act-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          staffName: handledBy,
          action: 'Prioritas Diubah',
          note: 'Prioritas diubah dari ${existing.priority} ke $priority',
          createdAt: now,
        );

        final updated = existing.copyWith(
          priority: priority,
          updatedAt: now,
          handledBy: handledBy,
          activities: [newActivity, ...existing.activities],
        );
        _mockReports[idx] = updated;
        return updated.toJson();
      }
      return {'success': false, 'message': 'Report not found'};
    }

    return _api.post('/support-reports/$reportId/priority', body: {
      'priority': priority,
      'handled_by': handledBy,
    });
  }

  /// Adds a public reply to reporter (FR-99).
  Future<Map<String, dynamic>> addReply({
    required String reportId,
    required String message,
    String senderName = 'Admin Platform',
    String senderRole = 'Admin Platform',
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final idx = _mockReports.indexWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      );

      if (idx != -1) {
        final existing = _mockReports[idx];
        final now = DateTime.now();

        final newReply = ReportReplyModel(
          id: 'rep-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          senderName: senderName,
          senderRole: senderRole,
          message: message,
          createdAt: now,
        );

        final newActivity = ReportActivityModel(
          id: 'act-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          staffName: senderName,
          action: 'Balasan Terkirim',
          note: 'Balasan publik dikirim kepada pelapor',
          createdAt: now,
        );

        final updated = existing.copyWith(
          updatedAt: now,
          handledBy: senderName,
          replies: [...existing.replies, newReply],
          activities: [newActivity, ...existing.activities],
        );
        _mockReports[idx] = updated;
        return updated.toJson();
      }
      return {'success': false, 'message': 'Report not found'};
    }

    return _api.post('/support-reports/$reportId/reply', body: {
      'message': message,
      'sender_name': senderName,
      'sender_role': senderRole,
    });
  }

  /// Adds an internal confidential note (FR-99, FR-101).
  Future<Map<String, dynamic>> addInternalNote({
    required String reportId,
    required String note,
    String authorName = 'Admin Platform',
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final idx = _mockReports.indexWhere(
        (r) => r.id == reportId || r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      );

      if (idx != -1) {
        final existing = _mockReports[idx];
        final now = DateTime.now();

        final newNote = ReportInternalNoteModel(
          id: 'not-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          authorName: authorName,
          note: note,
          createdAt: now,
        );

        final newActivity = ReportActivityModel(
          id: 'act-${now.millisecondsSinceEpoch}',
          reportId: existing.id,
          staffName: authorName,
          action: 'Catatan Internal Ditambahkan',
          note: 'Catatan internal baru dicatat (khusus admin)',
          createdAt: now,
        );

        final updated = existing.copyWith(
          updatedAt: now,
          internalNotes: [...existing.internalNotes, newNote],
          activities: [newActivity, ...existing.activities],
        );
        _mockReports[idx] = updated;
        return updated.toJson();
      }
      return {'success': false, 'message': 'Report not found'};
    }

    return _api.post('/support-reports/$reportId/internal-note', body: {
      'note': note,
      'author_name': authorName,
    });
  }
}
