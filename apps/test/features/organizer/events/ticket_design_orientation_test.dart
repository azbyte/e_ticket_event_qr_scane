import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/widgets/ticket_design_panel.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_design_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/models/ticket/ticket_model.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/ticket_design_service.dart';

/// Fake service agar panel diuji tanpa HTTP.
class _FakeTicketDesignService extends TicketDesignService {
  _FakeTicketDesignService(this._state);

  final TicketDesignState _state;
  final List<TicketOrientation> savedOrientations = <TicketOrientation>[];
  final List<String> openedScopes = <String>[];
  final List<TicketQrPlacement> savedQrPlacements = <TicketQrPlacement>[];

  @override
  Future<TicketDesignState> load(String eventId) async => _state;

  @override
  Future<TicketDesignModel> saveOrientation({
    required String eventId,
    required TicketOrientation orientation,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    savedOrientations.add(orientation);
    openedScopes.add(scope);
    return TicketDesignModel(
      filePath: '',
      contentType: 'image/png',
      orientation: orientation,
    );
  }

  @override
  Future<TicketDesignModel> saveQrPlacement({
    required String eventId,
    required TicketQrPlacement qr,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    savedQrPlacements.add(qr);
    openedScopes.add(scope);
    return TicketDesignModel(
      filePath: '/media/ticket-designs/evt-1/desain.png',
      contentType: 'image/png',
      orientation: TicketOrientation.landscape,
      qr: qr,
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('Orientasi desain tiket', () {
    test('TicketOrientation.fromValue memetakan nilai API dengan aman', () {
      expect(TicketOrientation.fromValue('portrait'), TicketOrientation.portrait);
      expect(TicketOrientation.fromValue('LANDSCAPE'), TicketOrientation.landscape);
      expect(TicketOrientation.fromValue(null), TicketOrientation.landscape);
      expect(TicketOrientation.fromValue('diagonal'), TicketOrientation.landscape);
    });

    test('rasio kanvas landscape horizontal dan portrait vertikal', () {
      expect(TicketOrientation.landscape.widthToHeightRatio, greaterThan(1));
      expect(TicketOrientation.portrait.widthToHeightRatio, lessThan(1));
    });

    test('default QR & area info mengikuti orientasi', () {
      final portraitQr = TicketDesignModel.defaultQrFor(TicketOrientation.portrait);
      final landscapeQr =
          TicketDesignModel.defaultQrFor(TicketOrientation.landscape);
      expect(portraitQr.y, isNot(landscapeQr.y));
      final portraitInfo =
          TicketDesignModel.defaultInfoFor(TicketOrientation.portrait);
      expect(portraitInfo.width,
        greaterThan(TicketDesignModel.defaultInfo.width));
    });

    test('TicketDesignState mewarisi orientasi event untuk kategori', () {
      final state = TicketDesignState.fromJson(<String, dynamic>{
        'event_orientation': 'portrait',
        'event_design': null,
        'ticket_types': <dynamic>[
          <String, dynamic>{
            'id': 'tt-1',
            'name': 'Reguler',
            'orientation': 'portrait',
            'design': <String, dynamic>{'orientation': 'portrait'},
          },
        ],
      });
      expect(state.eventOrientation, TicketOrientation.portrait);
      expect(state.orientationFor('tt-1'), TicketOrientation.portrait);
      expect(state.orientationFor(null), TicketOrientation.portrait);
      expect(state.orientationFor('tidak-ada'), TicketOrientation.portrait);
    });

    test('template URL membawa orientasi yang dipilih', () {
      final portraitUrl = TicketDesignService.templateUrl(
        'pdf',
        orientation: TicketOrientation.portrait,
      );
      expect(portraitUrl, contains('orientation=portrait'));
      final landscapeUrl = TicketDesignService.templateUrl(
        'png',
        orientation: TicketOrientation.landscape,
      );
      expect(landscapeUrl, contains('format=png'));
      expect(landscapeUrl, contains('orientation=landscape'));
    });
  });

  group('Panel desain tiket', () {
    testWidgets('menampilkan pilihan landscape & portrait', (tester) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.landscape),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-design-orientation')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-orientation-landscape')),
        findsOneWidget);
      expect(find.byKey(const Key('ticket-design-orientation-portrait')),
        findsOneWidget);
      // Penanda area QR tampil pada kanvas pratinjau.
      expect(find.byKey(const Key('ticket-design-qr-marker')), findsOneWidget);
    });

    testWidgets('memilih portrait lalu menyimpan mengirim orientasi ke API',
        (tester) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.landscape),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('ticket-design-orientation-portrait')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-design-orientation-save')),
        findsOneWidget);
      await tester.tap(find.byKey(const Key('ticket-design-orientation-save')));
      await tester.pumpAndSettle();

      expect(service.savedOrientations,
        <TicketOrientation>[TicketOrientation.portrait]);
      expect(service.openedScopes, <String>['event']);
    });

    testWidgets('tanpa perubahan tidak menampilkan tombol simpan',
        (tester) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.portrait),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-design-orientation-save')),
        findsNothing);
      expect(find.byKey(const Key('ticket-design-orientation-saved')),
        findsOneWidget);
    });
  });

  group('Pengaturan QR Code', () {
    test('clamped() membatasi nilai ke rentang slider/backend', () {
      const legacy = TicketQrPlacement(x: 1.4, y: -0.2, size: 0.9);
      final clamped = legacy.clamped();
      expect(clamped.x, TicketQrPlacement.maxPosition);
      expect(clamped.y, TicketQrPlacement.minPosition);
      expect(clamped.size, TicketQrPlacement.maxSize);
      // Nilai default sistem tidak berubah karena sudah di dalam rentang.
      expect(TicketDesignModel.defaultQr.clamped(), TicketDesignModel.defaultQr);
      expect(
        TicketDesignModel.defaultPortraitQr.clamped(),
        TicketDesignModel.defaultPortraitQr,
      );
    });

    testWidgets('desain lama dengan ukuran QR 90% tetap tampil tanpa error',
        (tester) async {
      final service = _FakeTicketDesignService(
        TicketDesignState(
          eventOrientation: TicketOrientation.landscape,
          eventDesign: const TicketDesignModel(
            filePath: '/media/ticket-designs/evt-1/desain.png',
            contentType: 'image/png',
            orientation: TicketOrientation.landscape,
            qr: TicketQrPlacement(x: 0.5, y: 0.5, size: 0.9),
          ),
        ),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      final sizeSlider =
          tester.widget<Slider>(find.byKey(const Key('ticket-design-qr-size')));
      expect(sizeSlider.value, TicketQrPlacement.maxSize);
      expect(tester.takeException(), isNull);
    });

    testWidgets('panel menyediakan slider X, Y, ukuran dan tombol simpan',
        (tester) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.landscape),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-design-qr-x')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-y')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-size')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-save')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-reset')), findsOneWidget);
      // Tanpa desain unggahan, pengaturan QR belum dapat disimpan.
      expect(find.byKey(const Key('ticket-design-qr-status')), findsOneWidget);
    });

    testWidgets('tanpa desain unggahan tombol simpan QR tidak mengirim API',
        (tester) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.landscape),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('ticket-design-qr-save')),
      );
      expect(saveButton.onPressed, isNull);
      expect(service.savedQrPlacements, isEmpty);
    });

    testWidgets('menggeser slider vertikal lalu menyimpan mengirim posisi QR',
        (tester) async {
      const savedQr = TicketQrPlacement(x: 0.2, y: 0.3, size: 0.35);
      final service = _FakeTicketDesignService(
        TicketDesignState(
          eventOrientation: TicketOrientation.landscape,
          eventDesign: const TicketDesignModel(
            filePath: '/media/ticket-designs/evt-1/desain.png',
            contentType: 'image/png',
            orientation: TicketOrientation.landscape,
            qr: savedQr,
          ),
        ),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      // Pengaturan tersimpan dimuat ke slider (bukan default sistem).
      final ySlider = find.byKey(const Key('ticket-design-qr-y'));
      await tester.ensureVisible(ySlider);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(ySlider).value, closeTo(savedQr.y, 0.001));

      await tester.drag(ySlider, const Offset(120, 0));
      await tester.pumpAndSettle();
      final draggedY = tester.widget<Slider>(ySlider).value;
      expect(draggedY, greaterThan(savedQr.y));

      final saveButtonFinder = find.byKey(const Key('ticket-design-qr-save'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      final saveButton = tester.widget<FilledButton>(saveButtonFinder);
      expect(saveButton.onPressed, isNotNull, reason: 'perubahan QR terdeteksi');

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(service.savedQrPlacements, hasLength(1));
      expect(service.savedQrPlacements.single.y, closeTo(draggedY, 0.001));
      expect(service.openedScopes, contains('event'));
    });

    testWidgets('tombol atur ulang default mengembalikan QR default sistem',
        (tester) async {
      final service = _FakeTicketDesignService(
        TicketDesignState(
          eventOrientation: TicketOrientation.landscape,
          eventDesign: const TicketDesignModel(
            filePath: '/media/ticket-designs/evt-1/desain.png',
            contentType: 'image/png',
            orientation: TicketOrientation.landscape,
            qr: TicketQrPlacement(x: 0.6, y: 0.6, size: 0.5),
          ),
        ),
      );
      await tester.pumpWidget(_wrap(TicketDesignPanel(
        eventId: 'evt-1',
        ticketTypes: const <TicketTypeModel>[],
        service: service,
      )));
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('ticket-design-qr-reset'));
      await tester.ensureVisible(resetButton);
      await tester.pumpAndSettle();
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      final defaultQr = TicketDesignModel.defaultQr;
      expect(
        tester.widget<Slider>(find.byKey(const Key('ticket-design-qr-x'))).value,
        closeTo(defaultQr.x, 0.001),
      );
      expect(
        tester.widget<Slider>(find.byKey(const Key('ticket-design-qr-y'))).value,
        closeTo(defaultQr.y, 0.001),
      );
      expect(
        tester.widget<Slider>(find.byKey(const Key('ticket-design-qr-size'))).value,
        closeTo(defaultQr.size, 0.001),
      );
    });
  });

  group('Nama event pada tiket', () {
    test('TicketModel memakai event_title dari API', () {
      final ticket = TicketModel.fromJson(<String, dynamic>{
        'id': 'tkt-1',
        'order_id': 'ord-1',
        'event_id': 'evt-1',
        'ticket_type_id': 'tt-1',
        'attendee_name': 'Peserta',
        'token': 'token',
        'status': 'valid',
        'event_title': 'Konser Nama Asli',
        'ticket_type_name': 'Reguler',
        'ticket_code': 'TKT-1',
        'event_location': 'Jakarta',
      });
      expect(ticket.displayEventTitle, 'Konser Nama Asli');
      expect(ticket.displayTicketType, 'Reguler');
      expect(ticket.displayLocation, 'Jakarta');
    });

    test('TicketModel memakai objek events bila field datar tidak ada', () {
      final ticket = TicketModel.fromJson(<String, dynamic>{
        'id': 'tkt-2',
        'order_id': 'ord-2',
        'event_id': 'evt-2',
        'ticket_type_id': 'tt-2',
        'attendee_name': 'Peserta',
        'token': 'token',
        'status': 'valid',
        'events': <String, dynamic>{'title': 'Event Dari Relasi'},
      });
      expect(ticket.displayEventTitle, 'Event Dari Relasi');
    });

    test('nama event kosong tidak menampilkan null atau UUID', () {
      final ticket = TicketModel.fromJson(<String, dynamic>{
        'id': 'tkt-3',
        'event_id': 'evt-3',
        'ticket_type_id': 'tt-3',
        'attendee_name': 'Peserta',
        'token': 'token',
        'status': 'valid',
      });
      expect(ticket.displayEventTitle, 'Nama event tidak tersedia');
      expect(ticket.displayEventTitle, isNot(contains('null')));
      expect(ticket.displayEventTitle, isNot(contains('evt-3')));
    });
  });
}

