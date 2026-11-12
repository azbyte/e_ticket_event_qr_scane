import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/attendee_list_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  testWidgets('staff without participant permission cannot see attendee data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendeeListScreen(
          initialMembershipContext: OrganizerMembershipContext.staff(
            eventId: 'evt-1001',
            userName: 'Staf Pintu Masuk',
            permissions: {
              OrganizerPermission.scanTicket,
              OrganizerPermission.checkInTicket,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Akses daftar peserta tidak tersedia untuk peran ini.'),
      findsOneWidget,
    );
    expect(find.text('Total Peserta'), findsNothing);
    expect(find.text('Ahmad Fauzi'), findsNothing);
  });
}
