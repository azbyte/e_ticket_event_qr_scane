/// Model desain tiket (PRD §5).
///
/// Satu desain terdiri dari file gambar yang diunggah Organizer plus penanda
/// posisi QR dan area teks informasi. Posisi disimpan sebagai fraksi 0..1 dari
/// kanvas tiket sehingga tidak bergantung pada resolusi file.
class TicketDesignModel {
  const TicketDesignModel({
    required this.filePath,
    required this.contentType,
    this.url,
    this.source = 'upload',
    this.template = 'custom',
    this.qr = defaultQr,
    this.info = defaultInfo,
    this.updatedAt,
  });

  /// Posisi QR default: kiri 74%, atas 25%, sisi 50% tinggi kanvas.
  static const TicketQrPlacement defaultQr = TicketQrPlacement(
    x: 0.74,
    y: 0.25,
    size: 0.5,
  );

  /// Area teks default (sisi kiri tiket).
  static const TicketInfoPlacement defaultInfo = TicketInfoPlacement(
    x: 0.34,
    y: 0.2,
    width: 0.36,
    height: 0.66,
    color: '#111111',
  );

  /// Path relatif di server, mis. `/media/ticket-designs/{eventId}/{file}.png`.
  final String filePath;

  /// `image/png` atau `image/jpeg`.
  final String contentType;
  final String? url;
  final String source;
  final String template;
  final TicketQrPlacement qr;
  final TicketInfoPlacement info;
  final DateTime? updatedAt;

  factory TicketDesignModel.fromJson(Map<String, dynamic> json) {
    final qrRaw = json['qr'];
    final infoRaw = json['info'];
    return TicketDesignModel(
      filePath: json['file_path']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? 'image/png',
      url: json['url']?.toString(),
      source: json['source']?.toString() ?? 'upload',
      template: json['template']?.toString() ?? 'custom',
      qr: qrRaw is Map
          ? TicketQrPlacement.fromJson(Map<String, dynamic>.from(qrRaw))
          : defaultQr,
      info: infoRaw is Map
          ? TicketInfoPlacement.fromJson(Map<String, dynamic>.from(infoRaw))
          : defaultInfo,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'file_path': filePath,
    'content_type': contentType,
    'source': source,
    'template': template,
    'qr': qr.toJson(),
    'info': info.toJson(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

/// Posisi & ukuran QR pada kanvas tiket (fraksi 0..1).
class TicketQrPlacement {
  const TicketQrPlacement({
    required this.x,
    required this.y,
    required this.size,
  });

  final double x;
  final double y;
  final double size;

  TicketQrPlacement copyWith({double? x, double? y, double? size}) =>
      TicketQrPlacement(
        x: x ?? this.x,
        y: y ?? this.y,
        size: size ?? this.size,
      );

  factory TicketQrPlacement.fromJson(Map<String, dynamic> json) =>
      TicketQrPlacement(
        x: (json['x'] as num? ?? 0.74).toDouble(),
        y: (json['y'] as num? ?? 0.25).toDouble(),
        size: (json['size'] as num? ?? 0.5).toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'size': size,
  };
}

/// Area teks informasi peserta pada kanvas tiket (fraksi 0..1).
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

  factory TicketInfoPlacement.fromJson(Map<String, dynamic> json) =>
      TicketInfoPlacement(
        x: (json['x'] as num? ?? 0.34).toDouble(),
        y: (json['y'] as num? ?? 0.2).toDouble(),
        width: (json['width'] as num? ?? 0.36).toDouble(),
        height: (json['height'] as num? ?? 0.66).toDouble(),
        color: json['color']?.toString() ?? '#111111',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'color': color,
  };
}

/// Hasil pemuatan desain untuk satu event (default + per kategori).
class TicketDesignState {
  const TicketDesignState({
    this.eventDesign,
    this.ticketTypeDesigns = const <String, TicketDesignModel>{},
  });

  final TicketDesignModel? eventDesign;
  final Map<String, TicketDesignModel> ticketTypeDesigns;

  factory TicketDesignState.fromJson(Map<String, dynamic> json) {
    final eventDesignRaw = json['event_design'];
    final designs = <String, TicketDesignModel>{};
    final types = json['ticket_types'];
    if (types is List) {
      for (final row in types) {
        if (row is! Map) continue;
        final id = row['id']?.toString();
        final design = row['design'];
        if (id == null || design is! Map) continue;
        designs[id] = TicketDesignModel.fromJson(
          Map<String, dynamic>.from(design),
        );
      }
    }
    return TicketDesignState(
      eventDesign: eventDesignRaw is Map
          ? TicketDesignModel.fromJson(
              Map<String, dynamic>.from(eventDesignRaw),
            )
          : null,
      ticketTypeDesigns: designs,
    );
  }
}
