/// Ringkasan status pengiriman e-ticket melalui email.
///
/// Nilai ini berasal dari respons backend (`email_delivery`) dan menunjukkan
/// keadaan sebenarnya: `delivered` hanya true bila email benar-benar diterima
/// transport SMTP. Aplikasi tidak boleh menampilkan "email terkirim" hanya
/// berdasarkan keberhasilan pembayaran.
class EmailDeliverySummary {
  const EmailDeliverySummary({
    this.configured = false,
    this.transport = 'disabled',
    this.delivered = false,
    this.queued = false,
    this.status = 'PENDING',
    this.results = const <EmailDeliveryResult>[],
  });

  /// True hanya bila SMTP nyata dikonfigurasi di server.
  final bool configured;

  /// Mode transport backend: `smtp`, `json` (uji), atau `disabled`.
  final String transport;

  /// True bila seluruh tiket pada order sudah benar-benar terkirim.
  final bool delivered;

  /// True bila pengiriman masih diproses di antrean server.
  final bool queued;

  /// Ringkasan status: SENT, QUEUED, PENDING, FAILED, NOT_CONFIGURED.
  final String status;

  final List<EmailDeliveryResult> results;

  bool get isSending =>
      queued || results.any((item) => item.status == 'SENDING');

  /// Ada tiket yang benar-benar gagal dikirim (bukan sekadar menunggu).
  bool get hasFailure =>
      status == 'FAILED' || results.any((item) => item.status == 'FAILED');

  /// Pesan siap tampil untuk peserta (jujur, tanpa klaim berlebihan).
  String get message {
    if (delivered) {
      return 'E-ticket PDF telah dikirim ke email peserta.';
    }
    if (isSending) {
      return 'E-ticket PDF sedang diproses untuk dikirim ke email peserta. '
          'Buka tiket untuk melihat status terbaru atau mengirim ulang.';
    }
    if (transport == 'disabled' || status == 'NOT_CONFIGURED') {
      return 'E-ticket tersedia di aplikasi, tetapi layanan email belum '
          'dikonfigurasi di server sehingga email belum terkirim.';
    }
    if (results.isEmpty) {
      return 'Status pengiriman email belum tersedia.';
    }
    if (hasFailure) {
      return 'E-ticket tersedia di aplikasi, tetapi email belum berhasil '
          'dikirim. Silakan buka tiket lalu gunakan "Kirim ulang email".';
    }
    return 'E-ticket tersedia di aplikasi dan email belum terkirim. '
        'Buka tiket untuk mengirim ulang.';
  }

  factory EmailDeliverySummary.fromJson(Object? raw) {
    if (raw is! Map) return const EmailDeliverySummary();
    final map = Map<String, dynamic>.from(raw);
    final resultsRaw = map['results'];
    final results = <EmailDeliveryResult>[];
    if (resultsRaw is List) {
      for (final row in resultsRaw) {
        if (row is! Map) continue;
        results.add(
          EmailDeliveryResult.fromJson(Map<String, dynamic>.from(row)),
        );
      }
    }
    return EmailDeliverySummary(
      configured: map['configured'] == true,
      transport: map['transport']?.toString() ?? 'disabled',
      delivered: map['delivered'] == true,
      queued: map['queued'] == true,
      status: map['status']?.toString() ??
          (map['delivered'] == true ? 'SENT' : 'PENDING'),
      results: results,
    );
  }
}

/// Status satu email tiket.
class EmailDeliveryResult {
  const EmailDeliveryResult({
    this.ticketId,
    this.recipient,
    this.status = 'UNKNOWN',
    this.reason,
  });

  final String? ticketId;
  final String? recipient;

  /// `SENT`, `PENDING`, `FAILED`, `SKIPPED`, `NOT_CONFIGURED`, ...
  final String status;
  final String? reason;

  bool get isSent => status == 'SENT';

  factory EmailDeliveryResult.fromJson(Map<String, dynamic> json) =>
      EmailDeliveryResult(
        ticketId: json['ticket_id']?.toString(),
        recipient: json['recipient']?.toString(),
        status: json['status']?.toString() ?? 'UNKNOWN',
        reason: json['reason']?.toString(),
      );
}
