/// Organizer support and complaint ticket service (FR-95, FR-96).
///
/// Implements organizer help center, complaint ticket submission, secure status tracking,
/// public response history, while strictly concealing admin internal notes per PRD specifications.
library;

import '../../models/report/support_report_model.dart';
import '../report/report_service.dart';

class ComplaintReplyModel {
  final String sender; // 'Admin Platform' or 'Penyelenggara'
  final String message;
  final DateTime sentAt;

  const ComplaintReplyModel({
    required this.sender,
    required this.message,
    required this.sentAt,
  });
}

class OrganizerComplaintModel {
  final String id;
  final String ticketNumber; // e.g. RPT-ORG-2026-001
  final String statusToken;
  final String organizerId;
  final String organizerEmail;
  final String category;
  final String subject;
  final String description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ComplaintReplyModel> replies;

  const OrganizerComplaintModel({
    required this.id,
    required this.ticketNumber,
    required this.statusToken,
    required this.organizerId,
    required this.organizerEmail,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });
}

class OrganizerFaqItem {
  final String question;
  final String answer;
  final String category;

  const OrganizerFaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class OrganizerSupportService {
  OrganizerSupportService._internal();
  static final OrganizerSupportService instance =
      OrganizerSupportService._internal();
  factory OrganizerSupportService() => instance;

  static const String demoOrganizerId = 'org-001';
  static const String demoOrganizerEmail = 'nadia@demo.eticket.local';

  final ReportService _reportService = ReportService();

  static const List<OrganizerFaqItem> _faqList = [
    OrganizerFaqItem(
      category: 'Event & Moderasi',
      question: 'Berapa lama proses moderasi event berlangsung?',
      answer: 'Proses moderasi event umumnya membutuhkan waktu 1x24 jam kerja setelah diajukan oleh penyelenggara.',
    ),
    OrganizerFaqItem(
      category: 'Staf & Pemindai QR',
      question: 'Apakah staf event perlu membuat akun terpisah?',
      answer: 'Staf cukup mendaftar atau login menggunakan email yang sama dengan email undangan. Hak akses akan otomatis terhubung ke event yang ditentukan.',
    ),
    OrganizerFaqItem(
      category: 'Mode Offline',
      question:
          'Bagaimana jika koneksi internet terputus saat proses check-in?',
      answer: 'Aplikasi scanner mendukung mode offline lokal. Data kehadiran akan disimpan di antrean perangkat dan dapat disinkronkan saat online kembali.',
    ),
    OrganizerFaqItem(
      category: 'Paket & Batasan',
      question: 'Kapan batasan kuota tiket di-reset?',
      answer: 'Kuota tiket berlaku per-event aktif sesuai dengan paket langganan yang sedang berjalan pada akun Organizer Anda.',
    ),
  ];

  /// Lists complaints submitted by an organizer.
  Future<List<OrganizerComplaintModel>> listComplaints(
    String organizerId,
  ) async {
    final reports = await _reportService.listReports();
    return List<OrganizerComplaintModel>.unmodifiable(
      reports
          .map(
            (report) => SupportReportModel.fromJson(report),
          )
          .where((report) => report.userId == organizerId)
          .map(_toOrganizerComplaint)
          .toList(growable: false),
    );
  }

  /// Creates a new support complaint.
  Future<OrganizerComplaintModel> submitComplaint({
    required String organizerId,
    required String email,
    required String category,
    required String subject,
    required String description,
  }) async {
    final report = await _reportService.createReport({
      'user_id': organizerId,
      'contact_email': email,
      'category': _toReportCategory(category),
      'subject': subject,
      'description': description,
    });
    return _toOrganizerComplaint(SupportReportModel.fromJson(report));
  }

  OrganizerComplaintModel _toOrganizerComplaint(SupportReportModel report) {
    final token = report.statusToken;
    if (token == null || token.isEmpty) {
      throw StateError('Laporan ${report.id} tidak memiliki token status.');
    }

    return OrganizerComplaintModel(
      id: report.id,
      ticketNumber: report.ticketNumber,
      statusToken: token,
      organizerId: report.userId ?? '',
      organizerEmail: report.contactEmail ?? '',
      category: _toOrganizerCategory(report.category),
      subject: report.subject,
      description: report.description,
      status: report.status,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
      replies: report.replies
          .map(
            (reply) => ComplaintReplyModel(
              sender: reply.senderName,
              message: reply.message,
              sentAt: reply.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  String _toReportCategory(String category) => switch (category) {
        'Moderasi Event' => 'EVENT',
        'Pembayaran' => 'PAYMENT',
        'Tiket Elektronik' => 'E_TICKET',
        'Scanner' => 'SCANNER',
        'Akun' => 'ACCOUNT',
        'Langganan' => 'SUBSCRIPTION',
        'Transaksi' => 'TRANSACTION',
        _ => 'OTHER',
      };

  String _toOrganizerCategory(String category) => switch (category) {
        'EVENT' => 'Moderasi Event',
        'PAYMENT' => 'Pembayaran',
        'E_TICKET' => 'Tiket Elektronik',
        'SCANNER' => 'Scanner',
        'ACCOUNT' => 'Akun',
        'SUBSCRIPTION' => 'Langganan',
        'TRANSACTION' => 'Transaksi',
        _ => category,
      };

  /// Gets FAQ list.
  List<OrganizerFaqItem> getFaqs() => _faqList;
}
