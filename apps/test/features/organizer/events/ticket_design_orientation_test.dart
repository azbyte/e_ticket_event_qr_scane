import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/widgets/ticket_design_panel.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_design_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/ticket_design_service.dart';

/// Fake service agar panel diuji tanpa HTTP.
class _FakeTicketDesignService extends TicketDesignService {
  _FakeTicketDesignService(this._state);

  final TicketDesignState _state;
  final List<TicketOrientation> savedOrientations = <TicketOrientation>[];
  final List<String> openedScopes = <String>[];
  final List<TicketLayoutModel> savedLayouts = <TicketLayoutModel>[];

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
      layout: TicketLayoutModel.defaultsFor(orientation),
    );
  }

  @override
  Future<TicketDesignModel> saveLayout({
    required String eventId,
    required TicketLayoutModel layout,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    savedLayouts.add(layout);
    openedScopes.add(scope);
    return TicketDesignModel(
      filePath: _state.eventDesign?.filePath ?? '',
      contentType: 'image/png',
      orientation: TicketOrientation.landscape,
      layout: layout,
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Panel desain dengan service palsu.
Widget _panel(_FakeTicketDesignService service) => _wrap(
  TicketDesignPanel(
    eventId: 'evt-1',
    eventTitle: 'Konser',
    ticketTypes: const <TicketTypeModel>[],
    service: service,
  ),
);

_FakeTicketDesignService _serviceWithLayout(TicketLayoutModel layout) =>
    _FakeTicketDesignService(
      TicketDesignState(
        eventOrientation: TicketOrientation.landscape,
        eventDesign: TicketDesignModel(
          filePath: '/media/ticket-designs/evt-1/desain.png',
          contentType: 'image/png',
          orientation: TicketOrientation.landscape,
          layout: layout,
        ),
      ),
    );

void main() {
  group('Orientasi desain tiket', () {
    test('TicketOrientation.fromValue memetakan nilai API dengan aman', () {
      expect(
        TicketOrientation.fromValue('portrait'),
        TicketOrientation.portrait,
      );
      expect(
        TicketOrientation.fromValue('LANDSCAPE'),
        TicketOrientation.landscape,
      );
      expect(TicketOrientation.fromValue(null), TicketOrientation.landscape);
      expect(
        TicketOrientation.fromValue('diagonal'),
        TicketOrientation.landscape,
      );
    });

    test('rasio kanvas landscape horizontal dan portrait vertikal', () {
      expect(TicketOrientation.landscape.widthToHeightRatio, greaterThan(1));
      expect(TicketOrientation.portrait.widthToHeightRatio, lessThan(1));
    });

    test('default tata letak mengikuti orientasi', () {
      final portraitQr = TicketDesignModel.defaultQrFor(
        TicketOrientation.portrait,
      );
      final landscapeQr = TicketDesignModel.defaultQrFor(
        TicketOrientation.landscape,
      );
      expect(portraitQr.y, isNot(landscapeQr.y));
      expect(
        TicketLayoutModel.defaultPortrait.textWidth,
        greaterThan(TicketLayoutModel.defaultLandscape.textWidth),
      );
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
      // Tata letak kategori tanpa konfigurasi memakai default portrait.
      expect(state.layoutFor('tt-1'), TicketLayoutModel.defaultPortrait);
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
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ticket-design-orientation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ticket-design-orientation-landscape')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ticket-design-orientation-portrait')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ticket-design-canvas')), findsOneWidget);
    });

    testWidgets('memilih portrait lalu menyimpan mengirim orientasi ke API', (
      tester,
    ) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.landscape),
      );
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('ticket-design-orientation-portrait')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ticket-design-orientation-save')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ticket-design-orientation-save')));
      await tester.pumpAndSettle();

      expect(service.savedOrientations, <TicketOrientation>[
        TicketOrientation.portrait,
      ]);
      expect(service.openedScopes, <String>['event']);
    });

    testWidgets('tanpa perubahan tidak menampilkan tombol simpan orientasi', (
      tester,
    ) async {
      final service = _FakeTicketDesignService(
        const TicketDesignState(eventOrientation: TicketOrientation.portrait),
      );
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ticket-design-orientation-save')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ticket-design-orientation-saved')),
        findsOneWidget,
      );
    });

    testWidgets('editor menyediakan kontrol untuk setiap elemen', (
      tester,
    ) async {
      final service = _serviceWithLayout(TicketLayoutModel.defaultLandscape);
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      for (final key in <String>[
        TicketElementKey.title,
        TicketElementKey.ticketId,
        TicketElementKey.instruction,
        TicketElementKey.qr,
      ]) {
        expect(
          find.byKey(Key('ticket-design-element-$key')),
          findsOneWidget,
          reason: 'chip elemen $key tersedia',
        );
      }
      // Elemen default terpilih adalah QR Code.
      expect(find.byKey(const Key('ticket-design-qr-x')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-y')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-size')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-larger')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-qr-smaller')), findsOneWidget);
      // Konfigurasi default valid: tidak ada peringatan tumpang tindih.
      expect(find.byKey(const Key('ticket-design-conflicts')), findsOneWidget);
      expect(
        find.text('Semua elemen terlihat dan tidak bertumpuk.'),
        findsOneWidget,
      );
    });

    testWidgets('memilih elemen teks menampilkan input angka ukuran huruf', (
      tester,
    ) async {
      final service = _serviceWithLayout(TicketLayoutModel.defaultLandscape);
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('ticket-design-element-title')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-design-element-title')));
      await tester.pumpAndSettle();

      final fieldFinder = find.byKey(
        const Key('ticket-design-title-font-size'),
      );
      await tester.ensureVisible(fieldFinder);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(fieldFinder);
      expect(field.controller?.text, '50', reason: 'judul default 50 pt');
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      // Ukuran huruf diatur lewat angka + tombol langkah, bukan slider.
      expect(
        find.byKey(const Key('ticket-design-title-font-size-increase')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ticket-design-title-font-size-decrease')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ticket-design-title-font-size-preset-30')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ticket-design-title-x')), findsOneWidget);
      expect(find.byKey(const Key('ticket-design-title-y')), findsOneWidget);

      // Nilai input mengikuti elemen yang dipilih (instruksi default 30 pt).
      final instructionChip = find.byKey(
        const Key('ticket-design-element-instruction'),
      );
      await tester.ensureVisible(instructionChip);
      await tester.pumpAndSettle();
      await tester.tap(instructionChip);
      await tester.pumpAndSettle();
      final instructionField = tester.widget<TextField>(
        find.byKey(const Key('ticket-design-instruction-font-size')),
      );
      expect(instructionField.controller?.text, '30');
    });

    testWidgets('mengetik ukuran huruf langsung mengubah tata letak', (
      tester,
    ) async {
      final service = _serviceWithLayout(TicketLayoutModel.defaultLandscape);
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('ticket-design-element-title')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-design-element-title')));
      await tester.pumpAndSettle();

      final fieldFinder = find.byKey(
        const Key('ticket-design-title-font-size'),
      );
      await tester.enterText(fieldFinder, '64');
      await tester.pumpAndSettle();

      expect(find.textContaining('ukuran huruf 64.0 pt'), findsOneWidget);
      expect(
        find.text('Ada perubahan tata letak yang belum disimpan.'),
        findsOneWidget,
      );
    });

    testWidgets('tombol +/- dan pilihan cepat menyesuaikan ukuran huruf', (
      tester,
    ) async {
      final service = _serviceWithLayout(TicketLayoutModel.defaultLandscape);
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('ticket-design-element-title')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-design-element-title')));
      await tester.pumpAndSettle();

      final increase = find.byKey(
        const Key('ticket-design-title-font-size-increase'),
      );
      await tester.ensureVisible(increase);
      await tester.pumpAndSettle();
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(find.textContaining('ukuran huruf 51.0 pt'), findsOneWidget);

      final decrease = find.byKey(
        const Key('ticket-design-title-font-size-decrease'),
      );
      await tester.tap(decrease);
      await tester.pump();
      await tester.tap(decrease);
      await tester.pumpAndSettle();
      expect(find.textContaining('ukuran huruf 49.0 pt'), findsOneWidget);

      final preset = find.byKey(
        const Key('ticket-design-title-font-size-preset-30'),
      );
      await tester.ensureVisible(preset);
      await tester.pumpAndSettle();
      await tester.tap(preset);
      await tester.pumpAndSettle();
      expect(find.textContaining('ukuran huruf 30.0 pt'), findsOneWidget);
    });

    testWidgets('angka di luar batas dipotong ke 8-120 pt saat dikonfirmasi', (
      tester,
    ) async {
      final service = _serviceWithLayout(TicketLayoutModel.defaultLandscape);
      await tester.pumpWidget(_panel(service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('ticket-design-element-title')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-design-element-title')));
      await tester.pumpAndSettle();

      final fieldFinder = find.byKey(
        const Key('ticket-design-title-font-size'),
      );
      await tester.enterText(fieldFinder, '500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('ukuran huruf 120.0 pt'), findsOneWidget);
      expect(
        find.text('Ukuran disesuaikan ke batas 8–120 pt.'),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(fieldFinder);
      expect(field.controller?.text, '120');

      // Nilai kosong dikembalikan ke ukuran terakhir yang valid.
      await tester.enterText(fieldFinder, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(field.controller?.text, '120');
    });
  });
}
