/// Organizer support and complaint ticket service (FR-95, FR-96).
///
/// Implements organizer help center, complaint ticket submission, secure status tracking,
/// public response history, while strictly concealing admin internal notes per PRD specifications.
library;

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

  static final List<OrganizerComplaintModel> _mockComplaints = [
    OrganizerComplaintModel(
      id: 'cmp-001',
      ticketNumber: 'RPT-ORG-2026-001',
      statusToken: 'tok-org-alpha-991',
      organizerId: 'org-001',
      organizerEmail: demoOrganizerEmail,
      category: 'Moderasi Event',
      subject: 'Permohonan percepatan review event Tech Innovation Summit',
      description: 'Event kami telah diajukan 2 hari lalu namun status masih pending review. Mohon bantuan konfirmasi dokumen perizinan tempat acara.',
      status: 'in_progress',
      createdAt: DateTime.now().subtract(const Duration(hours: 24)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      replies: [
        ComplaintReplyModel(
          sender: 'Penyelenggara',
          message: 'Halo admin, tiket acara kami sudah mulai dipromosikan, mohon bantuannya untuk peninjauan.',
          sentAt: DateTime.now().subtract(const Duration(hours: 24)),
        ),
        ComplaintReplyModel(
          sender: 'Admin Platform',
          message: 'Halo Tim Tech Innovation Summit. Dokumen perizinan Anda sudah kami terima dan sedang diverifikasi oleh tim kurasi acara.',
          sentAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
      ],
    ),
    OrganizerComplaintModel(
      id: 'cmp-002',
      ticketNumber: 'RPT-ORG-2026-002',
      statusToken: 'tok-org-beta-992',
      organizerId: 'org-001',
      organizerEmail: demoOrganizerEmail,
      category: 'Undangan Staf',
      subject: 'Email undangan staf panitia masuk ke folder spam',
      description:
          'Staf kami melaporkan tidak menerima email tautan aktivasi scanner.',
      status: 'resolved',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      replies: [
        ComplaintReplyModel(
          sender: 'Admin Platform',
          message: 'Masalah pengiriman telah dicek pada gateway email. Staf juga dapat login langsung menggunakan email terdaftar pada menu Staf Event.',
          sentAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    ),
  ];

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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List<OrganizerComplaintModel>.unmodifiable(
      _mockComplaints
          .where((complaint) => complaint.organizerId == organizerId)
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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final sequence = _mockComplaints.length + 1;
    final suffix = sequence.toString().padLeft(3, '0');
    final newComplaint = OrganizerComplaintModel(
      id: 'rpt-org-$suffix',
      ticketNumber: 'RPT-ORG-2026-$suffix',
      statusToken:
          'demo-status-org-$suffix-${DateTime.now().microsecondsSinceEpoch}',
      organizerId: organizerId,
      organizerEmail: email,
      category: category,
      subject: subject,
      description: description,
      status: 'open',
      createdAt: DateTime.now(),
      replies: [
        ComplaintReplyModel(
          sender: 'Penyelenggara',
          message: description,
          sentAt: DateTime.now(),
        ),
      ],
    );
    _mockComplaints.insert(0, newComplaint);
    return newComplaint;
  }

  /// Gets FAQ list.
  List<OrganizerFaqItem> getFaqs() => _faqList;
}
