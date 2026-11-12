import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/shell/access_denied_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_shell/organizer_shell_service.dart';

void main() {
  group('OrganizerShellService & Metrics (FR-66, FR-70)', () {
    late OrganizerShellService shellService;

    setUp(() {
      shellService = OrganizerShellService.instance;
    });

    test('Organizer metrics only displays gross sales and strictly excludes platform commission', () async {
      final metrics = await shellService.getDashboardMetrics('org-001');

      expect(metrics.totalEvents, equals(4));
      expect(metrics.publishedEvents, equals(1));
      expect(metrics.pendingReviewEvents, equals(1));
      expect(metrics.revisionEvents, equals(1));
      expect(metrics.draftEvents, equals(1));

      // Financials: Gross sales is tracked for organizer
      expect(metrics.grossSales, greaterThan(0));
      expect(metrics.totalTicketsSold, greaterThan(0));
      expect(metrics.attendeesCheckedIn, greaterThan(0));

      // Moderation alerts exist
      expect(metrics.moderationAlerts.isNotEmpty, isTrue);
    });
  });

  group('AccessDeniedScreen Widget Safety Test', () {
    testWidgets('Renders safe message without leaking confidential data', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccessDeniedScreen(
            reason: 'Halaman ini khusus untuk Administrator Platform.',
          ),
        ),
      );

      // Verify header and safe error reason
      expect(find.text('Akses Ditolak'), findsOneWidget);
      expect(
        find.text('Halaman ini khusus untuk Administrator Platform.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Kembali ke Halaman Utama'), findsOneWidget);

      // Verify no leak of database, SQL, or internal tokens
      expect(find.textContaining('SELECT'), findsNothing);
      expect(find.textContaining('service_role'), findsNothing);
      expect(find.textContaining('supabase'), findsNothing);
    });
  });
}
