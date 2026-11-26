import 'package:e_ticket_event_qr_scane/features/organizer/events/widgets/attendee_field_builder.dart';
import 'package:e_ticket_event_qr_scane/models/event/attendee_field_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AttendeeFieldBuilder (T3-D1-04)', () {
    testWidgets('menampilkan field yang ada beserta tipe dan kunci', (
      tester,
    ) async {
      final fields = <AttendeeFieldDefinition>[
        ...OrganizerAttendeeDefaults.definitions,
        const AttendeeFieldDefinition(
          key: 'ukuran_kaos',
          label: 'Ukuran Kaos',
          type: AttendeeFieldDefinition.typeSelect,
          required: true,
          options: <String>['S', 'M', 'L'],
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          AttendeeFieldBuilder(fields: fields, onChanged: (_) {}),
        ),
      );

      expect(find.text('Nama lengkap *'), findsOneWidget);
      expect(find.text('Email *'), findsOneWidget);
      expect(find.text('Ukuran Kaos *'), findsOneWidget);
      expect(find.textContaining('Pilihan (dropdown)'), findsOneWidget);
      expect(find.textContaining('key: ukuran_kaos'), findsOneWidget);
    });

    testWidgets('tambah field select menambahkan opsi ke daftar', (
      tester,
    ) async {
      List<AttendeeFieldDefinition>? latest;
      await tester.pumpWidget(
        _wrap(
          AttendeeFieldBuilder(
            fields: OrganizerAttendeeDefaults.definitions,
            onChanged: (value) => latest = value,
          ),
        ),
      );

      await tester.tap(find.text('Tambah field'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Label pertanyaan'),
        'Kota Asal',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kunci field'),
        'kota_asal',
      );
      await tester.tap(find.text('Tipe field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilihan (dropdown)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Opsi (pisahkan dengan koma)'),
        'Jakarta, Bandung',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      final added = latest!.firstWhere((field) => field.key == 'kota_asal');
      expect(added.label, 'Kota Asal');
      expect(added.type, AttendeeFieldDefinition.typeSelect);
      expect(added.options, <String>['Jakarta', 'Bandung']);
    });

    testWidgets('kunci ganda ditolak dengan pesan jelas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AttendeeFieldBuilder(
            fields: OrganizerAttendeeDefaults.definitions,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Tambah field'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Label pertanyaan'),
        'Nama Lagi',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Kunci field'),
        'name',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sudah dipakai'), findsOneWidget);
    });

    testWidgets('field wajib (name/email) tidak dapat dihapus', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: AttendeeFieldBuilder(
              fields: OrganizerAttendeeDefaults.definitions,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButtons = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .toList();
      expect(deleteButtons.length, 2);
      expect(deleteButtons.every((button) => button.onPressed == null), isTrue);
    });

    testWidgets('urutan field dapat diubah', (tester) async {
      List<AttendeeFieldDefinition>? latest;
      final fields = <AttendeeFieldDefinition>[
        ...OrganizerAttendeeDefaults.definitions,
        const AttendeeFieldDefinition(key: 'instansi', label: 'Instansi'),
      ];
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: AttendeeFieldBuilder(
              fields: fields,
              onChanged: (value) => latest = value,
            ),
          ),
        ),
      );

      final upButtons = find.byIcon(Icons.arrow_upward);
      await tester.ensureVisible(upButtons.last);
      await tester.pumpAndSettle();
      await tester.tap(upButtons.last);
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest![1].key, 'instansi');
    });
  });
}
