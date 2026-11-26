import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/models/event/attendee_field_definition.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/payment/email_delivery_model.dart';

void main() {
  test('ensureRequiredFields menambahkan email wajib setelah nama', () {
    final fields = AttendeeFieldDefinition.ensureRequiredFields(
      const <AttendeeFieldDefinition>[
        AttendeeFieldDefinition(
          key: 'name',
          label: 'Nama lengkap',
          required: true,
        ),
        AttendeeFieldDefinition(
          key: 'shirt_size',
          label: 'Ukuran kaos',
          type: AttendeeFieldDefinition.typeSelect,
          options: <String>['M', 'L'],
        ),
      ],
    );
    expect(fields.map((field) => field.key), <String>[
      'name',
      'email',
      'shirt_size',
    ]);
    final email = fields.firstWhere((field) => field.key == 'email');
    expect(email.required, isTrue);
    expect(email.type, AttendeeFieldDefinition.typeText);
    // Field dinamis Organizer tidak berubah.
    expect(
      fields.firstWhere((field) => field.key == 'shirt_size').options,
      <String>['M', 'L'],
    );
  });

  test('email tidak dapat dijadikan opsional atau bertipe lain', () {
    final fields = AttendeeFieldDefinition.ensureRequiredFields(
      const <AttendeeFieldDefinition>[
        AttendeeFieldDefinition(
          key: 'email',
          label: 'Email',
          type: AttendeeFieldDefinition.typeNumber,
          required: false,
        ),
      ],
    );
    final email = fields.firstWhere((field) => field.key == 'email');
    expect(email.required, isTrue);
    expect(email.type, AttendeeFieldDefinition.typeText);
  });

  test('resolvedAttendeeFields event bertipe tetap memuat email', () {
    final event = EventModel(
      id: 'evt-1',
      organizerId: 'org-1',
      title: 'Seminar',
      startDateTime: DateTime(2026, 12, 1),
      endDateTime: DateTime(2026, 12, 1, 2),
      eventType: 'offline',
      status: 'published',
      attendeeFieldDefinitions: const <AttendeeFieldDefinition>[
        AttendeeFieldDefinition(
          key: 'name',
          label: 'Nama',
          required: true,
        ),
      ],
    );
    expect(
      event.resolvedAttendeeFields.map((field) => field.key),
      contains('email'),
    );
  });

  test('status email antre tidak diklaim terkirim', () {
    final queued = EmailDeliverySummary.fromJson(<String, dynamic>{
      'configured': true,
      'transport': 'smtp',
      'delivered': false,
      'queued': true,
      'status': 'QUEUED',
      'results': <dynamic>[
        <String, dynamic>{'ticket_id': 't1', 'status': 'QUEUED'},
      ],
    });
    expect(queued.delivered, isFalse);
    expect(queued.isSending, isTrue);
    expect(queued.message, contains('sedang diproses'));
  });

  test('SMTP belum dikonfigurasi dijelaskan tanpa klaim terkirim', () {
    final notConfigured = EmailDeliverySummary.fromJson(<String, dynamic>{
      'configured': false,
      'transport': 'disabled',
      'delivered': false,
      'queued': false,
      'status': 'NOT_CONFIGURED',
      'results': <dynamic>[
        <String, dynamic>{'ticket_id': 't1', 'status': 'NOT_CONFIGURED'},
      ],
    });
    expect(notConfigured.delivered, isFalse);
    expect(notConfigured.message, contains('belum dikonfigurasi'));
  });
}
