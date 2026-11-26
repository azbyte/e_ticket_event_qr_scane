import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/models/event/attendee_field_definition.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';

Map<String, dynamic> baseJson({Map<String, dynamic> overrides = const {}}) =>
    <String, dynamic>{
      'id': 'evt-1',
      'organizer_id': 'org-1',
      'title': 'Seminar Kontrak',
      'start_date_time': '2026-12-01T09:00:00.000Z',
      'end_date_time': '2026-12-01T12:00:00.000Z',
      'event_type': 'offline',
      'status': 'published',
      'is_public': true,
      ...overrides,
    };

void main() {
  group('EventModel — attendee_fields bertipe (D1-5)', () {
    test('array objek diparse menjadi definisi bertipe', () {
      final event = EventModel.fromJson(
        baseJson(
          overrides: {
            'attendee_fields': [
              {'key': 'name', 'label': 'Nama lengkap', 'type': 'text'},
              {'key': 'email', 'label': 'Email', 'type': 'text'},
              {
                'key': 'shirt_size',
                'label': 'Ukuran kaos',
                'type': 'select',
                'required': true,
                'options': ['S', 'M', 'L'],
              },
            ],
          },
        ),
      );

      expect(event.attendeeFields, ['name', 'email', 'shirt_size']);
      expect(event.attendeeFieldDefinitions.length, 3);
      final shirt = event.resolvedAttendeeFields.last;
      expect(shirt.type, AttendeeFieldDefinition.typeSelect);
      expect(shirt.required, isTrue);
      expect(shirt.options, ['S', 'M', 'L']);
      // name/email selalu required karena kolom tabel attendees.
      expect(event.resolvedAttendeeFields.first.required, isTrue);
    });

    test('array string legacy tetap didukung', () {
      final event = EventModel.fromJson(
        baseJson(
          overrides: {
            'attendee_fields': ['name', 'email', 'phone'],
          },
        ),
      );

      expect(event.attendeeFields, ['name', 'email', 'phone']);
      final fields = event.resolvedAttendeeFields;
      expect(fields.map((field) => field.key), ['name', 'email', 'phone']);
      expect(fields[2].type, AttendeeFieldDefinition.typeText);
      expect(fields[2].required, isFalse);
    });

    test('tanpa attendee_fields tidak melempar exception', () {
      final event = EventModel.fromJson(baseJson());
      expect(event.attendeeFields, isEmpty);
      // Pembaruan Tahap 3 (D1-04): server menolak event tanpa field `name` dan
      // `email` karena keduanya kolom wajib tabel `attendees`. Fallback model
      // kini menyertakan keduanya agar form publik dan form Organizer tetap
      // dapat merender dan menyimpan event lama tanpa konfigurasi field.
      expect(
        event.resolvedAttendeeFields.map((field) => field.key),
        containsAll(<String>['name', 'email']),
      );
      expect(
        event.resolvedAttendeeFields.every((field) => field.required),
        isTrue,
      );
    });
  });

  group('EventModel — tautan publik & alasan validasi (D1-2/D1-3)', () {
    test('public_url dari server dipakai apa adanya', () {
      final event = EventModel.fromJson(
        baseJson(overrides: {'public_url': 'https://tiket.test/e/evt-1'}),
      );
      expect(event.publicUrl, 'https://tiket.test/e/evt-1');
      expect(event.hasPublicLink, isTrue);
    });

    test('event tanpa public_url tidak memiliki tautan nyata', () {
      final event = EventModel.fromJson(baseJson(overrides: {'status': 'draft'}));
      expect(event.publicUrl, isNull);
      expect(event.hasPublicLink, isFalse);
    });

    test('validation_errors diparse menjadi daftar alasan', () {
      final event = EventModel.fromJson(
        baseJson(
          overrides: {
            'status': 'draft',
            'validation_errors': [
              'Minimal satu kategori tiket aktif diperlukan',
              'Lokasi wajib diisi untuk event offline/hybrid',
            ],
          },
        ),
      );

      expect(event.validationErrors.length, 2);
      expect(event.resolvedValidationErrors.first, contains('kategori tiket'));
    });

    test('reviewNote JSON array dipakai sebagai fallback alasan validasi', () {
      final event = EventModel.fromJson(
        baseJson(
          overrides: {
            'status': 'draft',
            'review_note': '["Minimal satu kategori tiket aktif diperlukan"]',
          },
        ),
      );

      expect(event.validationErrors, isEmpty);
      expect(event.resolvedValidationErrors, [
        'Minimal satu kategori tiket aktif diperlukan',
      ]);
    });

    test('reviewNote teks moderator tidak dianggap alasan validasi', () {
      final event = EventModel.fromJson(
        baseJson(overrides: {'review_note': 'Lengkapi poster.'}),
      );
      expect(event.resolvedValidationErrors, isEmpty);
      expect(event.reviewNote, 'Lengkapi poster.');
    });
  });
}
