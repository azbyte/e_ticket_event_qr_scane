/// Orientasi kanvas desain tiket (PRD §5).
///
/// Nilai string mengikuti kontrak backend (`landscape` / `portrait`) dan
/// disimpan di kolom `ticket_design_orientation` sehingga tetap ada walau
/// Organizer belum mengunggah file desain.
enum TicketOrientation {
  landscape('landscape', 'Landscape (horizontal)', 2.5),
  portrait('portrait', 'Portrait (vertikal)', 1 / 1.6);

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
    this.orientation = TicketOrientation.landscape,
    this.width,
    this.height,
    this.qr = defaultQr,
    this.info = defaultInfo,
    this.updatedAt,
  });

  /// Posisi QR default landscape: kiri 74%, atas 25%, sisi 50% tinggi kanvas.
  static const TicketQrPlacement defaultQr = TicketQrPlacement(
    x: 0.74,
    y: 0.25,
    size: 0.5,
  );

  /// Area teks default landscape (sisi kiri tiket).
  static const TicketInfoPlacement defaultInfo = TicketInfoPlacement(
    x: 0.34,
    y: 0.2,
    width: 0.36,
    height: 0.66,
    color: '#111111',
  );

  /// Posisi QR default portrait (bawah area informasi).
  static const TicketQrPlacement defaultPortraitQr = TicketQrPlacement(
    x: 0.32,
    y: 0.66,
    size: 0.28,
  );

  /// Area teks default portrait (lebar penuh di tengah kanvas).
  static const TicketInfoPlacement defaultPortraitInfo = TicketInfoPlacement(
    x: 0.08,
    y: 0.16,
    width: 0.84,
    height: 0.42,
    color: '#111111',
  );

  static TicketQrPlacement defaultQrFor(TicketOrientation orientation) =>
      orientation.isPortrait ? defaultPortraitQr : defaultQr;

  static TicketInfoPlacement defaultInfoFor(TicketOrientation orientation) =>
      orientation.isPortrait ? defaultPortraitInfo : defaultInfo;

  /// Path relatif di server, mis. `/media/ticket-designs/{eventId}/{file}.png`.
  final String filePath;

  /// `image/png` atau `image/jpeg`.
  final String contentType;
  final String? url;
  final String source;
  final String template;

  /// Orientasi kanvas yang dipilih Organizer.
  final TicketOrientation orientation;

  /// Dimensi file desain (px) bila sudah diunggah.
  final int? width;
  final int? height;
  final TicketQrPlacement qr;
  final TicketInfoPlacement info;
  final DateTime? updatedAt;

  /// True bila file desain benar-benar tersimpan (bukan hanya konfigurasi).
  bool get hasUploadedFile => filePath.isNotEmpty;

  /// Rasio file desain, null bila dimensi belum diketahui.
  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  factory TicketDesignModel.fromJson(Map<String, dynamic> json) {
    final qrRaw = json['qr'];
    final infoRaw = json['info'];
    final orientation = TicketOrientation.fromValue(json['orientation']);
    return TicketDesignModel(
      filePath: json['file_path']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? 'image/png',
      url: json['url']?.toString(),
      source: json['source']?.toString() ?? 'upload',
      template: json['template']?.toString() ?? 'custom',
      orientation: orientation,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      qr: qrRaw is Map
          ? TicketQrPlacement.fromJson(Map<String, dynamic>.from(qrRaw))
          : defaultQrFor(orientation),
      info: infoRaw is Map
          ? TicketInfoPlacement.fromJson(Map<String, dynamic>.from(infoRaw))
          : defaultInfoFor(orientation),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'file_path': filePath,
    'content_type': contentType,
    'source': source,
    'template': template,
    'orientation': orientation.value,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
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
    this.eventOrientation = TicketOrientation.landscape,
    this.ticketTypeOrientations = const <String, TicketOrientation>{},
    this.defaultOrientation = TicketOrientation.landscape,
  });

  final TicketDesignModel? eventDesign;
  final Map<String, TicketDesignModel> ticketTypeDesigns;

  /// Orientasi desain default seluruh event (tersimpan walau belum ada file).
  final TicketOrientation eventOrientation;

  /// Orientasi per kategori tiket.
  final Map<String, TicketOrientation> ticketTypeOrientations;

  /// Orientasi default sistem (dari backend).
  final TicketOrientation defaultOrientation;

  /// Orientasi efektif sebuah kategori: kategori -> event -> default sistem.
  TicketOrientation orientationFor(String? ticketTypeId) {
    if (ticketTypeId != null) {
      final perType = ticketTypeOrientations[ticketTypeId];
      if (perType != null) return perType;
      final design = ticketTypeDesigns[ticketTypeId];
      if (design?.hasUploadedFile == true) return design!.orientation;
    }
    if (eventDesign?.hasUploadedFile == true) return eventDesign!.orientation;
    return eventOrientation;
  }

  factory TicketDesignState.fromJson(Map<String, dynamic> json) {
    final eventDesignRaw = json['event_design'];
    final designs = <String, TicketDesignModel>{};
    final orientations = <String, TicketOrientation>{};
    final types = json['ticket_types'];
    if (types is List) {
      for (final row in types) {
        if (row is! Map) continue;
        final id = row['id']?.toString();
        final design = row['design'];
        if (id == null || design is! Map) continue;
        final model = TicketDesignModel.fromJson(
          Map<String, dynamic>.from(design),
        );
        designs[id] = model;
        orientations[id] = TicketOrientation.fromValue(
          row['orientation'] ?? model.orientation.value,
        );
      }
    }
    final eventModel = eventDesignRaw is Map
        ? TicketDesignModel.fromJson(Map<String, dynamic>.from(eventDesignRaw))
        : null;
    return TicketDesignState(
      eventDesign: eventModel,
      ticketTypeDesigns: designs,
      eventOrientation: TicketOrientation.fromValue(
        json['event_orientation'] ?? eventModel?.orientation.value,
      ),
      ticketTypeOrientations: orientations,
      defaultOrientation: TicketOrientation.fromValue(json['default_orientation']),
    );
  }
}
