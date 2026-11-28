/// Model desain tiket (PRD §5).
///
/// Satu desain terdiri dari konfigurasi tata letak (posisi/ukuran judul, ID
/// tiket, instruksi, dan QR — lihat `ticket_layout_model.dart`) plus OPSIONAL
/// berkas gambar yang diunggah Organizer. Konfigurasi tata letak tetap dapat
/// disimpan walau belum ada berkas gambar, karena tiket default sistem juga
/// memakai tata letak yang sama.
library;

import 'ticket_layout_model.dart';

export 'ticket_layout_model.dart';

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
    this.layout = TicketLayoutModel.defaultLandscape,
    this.updatedAt,
  });

  /// Posisi QR default landscape (x 5,95%, y 32,60%, sisi 42,31% tinggi
  /// kanvas) — nilai HARUS sama dengan `DEFAULT_LAYOUT_BY_ORIENTATION` di
  /// backend agar penanda QR pada pratinjau jatuh tepat di area QR tiket final.
  static const TicketQrPlacement defaultQr = TicketQrPlacement(
    x: 0.0595,
    y: 0.326,
    size: 0.4231,
  );

  /// Area teks default landscape (judul/ID/instruksi di kiri atas).
  static const TicketInfoPlacement defaultInfo = TicketInfoPlacement(
    x: 0.0445,
    y: 0.0286,
    width: 0.6,
    height: 0.2165,
    color: '#1A1A1A',
  );

  /// Posisi QR default portrait.
  static const TicketQrPlacement defaultPortraitQr = TicketQrPlacement(
    x: 0.07,
    y: 0.46,
    size: 0.36,
  );

  /// Area teks default portrait.
  static const TicketInfoPlacement defaultPortraitInfo = TicketInfoPlacement(
    x: 0.07,
    y: 0.042,
    width: 0.86,
    height: 0.152,
    color: '#1A1A1A',
  );

  static TicketQrPlacement defaultQrFor(TicketOrientation orientation) =>
      TicketLayoutModel.defaultsFor(orientation).qr;

  static TicketInfoPlacement defaultInfoFor(TicketOrientation orientation) =>
      orientation.isPortrait ? defaultPortraitInfo : defaultInfo;

  /// Tata letak default sistem untuk orientasi ini.
  static TicketLayoutModel defaultLayoutFor(TicketOrientation orientation) =>
      TicketLayoutModel.defaultsFor(orientation);

  /// Path relatif di server, mis. `/media/ticket-designs/{eventId}/{file}.png`.
  /// String kosong berarti belum ada berkas gambar (tiket memakai desain
  /// default sistem dengan tata letak yang tersimpan).
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

  /// Konfigurasi tata letak (posisi & ukuran seluruh elemen, termasuk QR).
  final TicketLayoutModel layout;
  final DateTime? updatedAt;

  /// Posisi & ukuran QR (cermin `layout.qr`, dipakai UI lama/ringkas).
  TicketQrPlacement get qr => layout.qr;

  /// Area teks (cermin `layout` untuk kompatibilitas tampilan ringkas).
  TicketInfoPlacement get info => TicketInfoPlacement(
    x: layout.title.x,
    y: layout.title.y,
    width: layout.textWidth,
    height: layout.instruction.y - layout.title.y,
    color: '#1A1A1A',
  );

  /// True bila file desain benar-benar tersimpan.
  bool get hasUploadedFile => filePath.isNotEmpty;

  /// True bila posisi/ukuran QR berbeda dari default orientasi ini.
  bool get hasCustomQr => layout.qr != defaultLayoutFor(orientation).qr;

  /// True bila tata letak berbeda dari default orientasi ini.
  bool get hasCustomLayout => layout != defaultLayoutFor(orientation);

  /// Rasio file desain, null bila dimensi belum diketahui.
  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  factory TicketDesignModel.fromJson(Map<String, dynamic> json) {
    final orientation = TicketOrientation.fromValue(json['orientation']);
    final layoutRaw = json['layout'];
    final fallback = TicketLayoutModel.defaultsFor(orientation);
    final TicketLayoutModel layout;
    if (layoutRaw is Map) {
      layout = TicketLayoutModel.fromJson(
        Map<String, dynamic>.from(layoutRaw),
        orientation: orientation,
      );
    } else if (json['qr'] is Map) {
      // Desain lama: hanya menyimpan posisi QR (dan mungkin area `info`).
      layout = fallback.copyWith(
        qr: TicketQrPlacement.fromJson(
          Map<String, dynamic>.from(json['qr'] as Map),
          fallback: fallback.qr,
        ),
      );
    } else {
      layout = fallback;
    }
    return TicketDesignModel(
      filePath: json['file_path']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? 'image/png',
      url: json['url']?.toString(),
      source: json['source']?.toString() ?? 'upload',
      template: json['template']?.toString() ?? 'custom',
      orientation: orientation,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      layout: layout,
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
    'layout': layout.toJson(),
    'qr': layout.qr.toJson(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}

/// Hasil pemuatan desain untuk satu event (default + per kategori).
///
/// `eventDesign` SELALU terisi setelah respons API: bila Organizer belum
/// mengunggah desain, nilainya adalah konfigurasi default sistem
/// (`filePath` kosong), sehingga editor dapat menampilkan dan mengubah tata
/// letak tiket default tanpa meminta unggahan.
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

  /// Tata letak efektif untuk scope terpilih: kategori -> event -> default.
  TicketLayoutModel layoutFor(String? ticketTypeId) {
    final design = ticketTypeId == null
        ? eventDesign
        : ticketTypeDesigns[ticketTypeId];
    if (design != null) return design.layout;
    return TicketLayoutModel.defaultsFor(orientationFor(ticketTypeId));
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

