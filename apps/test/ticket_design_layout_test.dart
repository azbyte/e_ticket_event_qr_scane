import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/models/event/ticket_design_model.dart';

void main() {
  // Nilai HARUS sama dengan `LANDSCAPE_CANVAS` / `PORTRAIT_CANVAS` di
  // backend/src/services/ticketDesignService.js agar penanda QR pada pratinjau
  // Organizer jatuh tepat pada QR tiket final.
  const landscapeWidth = 842.0;
  const landscapeHeight = 594.0;
  const portraitWidth = 440.0;
  const portraitHeight = 704.0;

  test('QR default landscape berukuran medium dan berada di bawah blok teks', () {
    final qr = TicketDesignModel.defaultQr;
    final side = qr.size * landscapeHeight;
    // Ukuran medium: cukup besar untuk dipindai, tidak mendominasi artwork.
    expect(side, inInclusiveRange(200, 240));
    expect(qr.x * landscapeWidth, closeTo(56, 0.001));
    expect(qr.y * landscapeHeight, closeTo(284, 0.001));
    // Teks kiri atas berakhir sebelum QR dimulai.
    final info = TicketDesignModel.defaultInfo;
    final infoBottom = (info.y + info.height) * landscapeHeight;
    expect(infoBottom, lessThanOrEqualTo(qr.y * landscapeHeight));
    // Blok teks tetap di dalam panel kiri (garis perforasi 470 pt).
    expect(info.x * landscapeWidth + info.width * landscapeWidth,
        lessThanOrEqualTo(470));
    // QR tidak keluar halaman.
    expect(qr.x * landscapeWidth + side, lessThanOrEqualTo(landscapeWidth));
    expect(qr.y * landscapeHeight + side, lessThanOrEqualTo(landscapeHeight));
  });

  test('QR default portrait berukuran medium dan berada di bawah blok teks', () {
    final qr = TicketDesignModel.defaultPortraitQr;
    final side = qr.size * portraitHeight;
    expect(side, inInclusiveRange(220, 260));
    expect(qr.x * portraitWidth, closeTo(36, 0.001));
    expect(qr.y * portraitHeight, closeTo(266, 0.001));
    final info = TicketDesignModel.defaultPortraitInfo;
    expect(
      (info.y + info.height) * portraitHeight,
      lessThanOrEqualTo(qr.y * portraitHeight),
    );
    expect(qr.y * portraitHeight + side, lessThanOrEqualTo(portraitHeight));
  });

  test('area teks default cukup tinggi untuk tipografi blok informasi', () {
    // Blok teks = 7 baris (34/23/16/16/16/16/14 pt) dengan jarak baris
    // proporsional ≈ 208 pt. Area default harus menampung tinggi alami tersebut
    // pada skala 1 agar tipografi tidak dikecilkan.
    const landscapeInfo = TicketDesignModel.defaultInfo;
    expect(landscapeInfo.height * landscapeHeight, greaterThanOrEqualTo(200));
    expect(landscapeInfo.width * landscapeWidth, greaterThanOrEqualTo(390));

    final portraitInfo = TicketDesignModel.defaultPortraitInfo;
    expect(portraitInfo.height * portraitHeight, greaterThanOrEqualTo(195));
    expect(portraitInfo.width * portraitWidth, greaterThanOrEqualTo(340));
  });

  test('warna teks default hitam agar kontras di atas artwork', () {
    expect(TicketDesignModel.defaultInfo.color, '#1A1A1A');
    expect(TicketDesignModel.defaultPortraitInfo.color, '#1A1A1A');
  });

  test('default per orientasi dipilih sesuai orientasi desain', () {
    expect(
      TicketDesignModel.defaultQrFor(TicketOrientation.portrait),
      TicketDesignModel.defaultPortraitQr,
    );
    expect(
      TicketDesignModel.defaultQrFor(TicketOrientation.landscape),
      TicketDesignModel.defaultQr,
    );
    expect(
      TicketDesignModel.defaultInfoFor(TicketOrientation.portrait),
      TicketDesignModel.defaultPortraitInfo,
    );
  });
}
