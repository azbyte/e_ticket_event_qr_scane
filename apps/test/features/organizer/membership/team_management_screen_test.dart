import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/errors/app_exception.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/membership/team_management_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/organizer_membership_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/staff_invitation_service.dart';

/// Service anggota palsu: tidak memanggil HTTP.
class _FakeMembershipService extends OrganizerMembershipService {
  _FakeMembershipService() : super(mockMode: true);

  int listCalls = 0;

  @override
  Future<List<EventMemberModel>> listMembers(
    String eventId, {
    String eventTitle = '',
  }) async {
    listCalls += 1;
    return const <EventMemberModel>[];
  }
}

/// Service undangan staf palsu: hasil diatur per test.
class _FakeInvitationService extends StaffInvitationService {
  _FakeInvitationService({
    this.created,
    this.regenerated,
    this.listError,
    this.createError,
    this.invitations = const <StaffInvitation>[],
  });

  final StaffInvitation? created;
  final StaffInvitation? regenerated;
  final Exception? listError;
  final Exception? createError;
  final List<StaffInvitation> invitations;

  int createCalls = 0;
  int regenerateCalls = 0;
  String? lastName;
  Iterable<String>? lastPermissions;

  @override
  Future<List<StaffInvitation>> list(String eventId) async {
    if (listError != null) throw listError!;
    return invitations;
  }

  @override
  Future<StaffInvitation> regenerate({
    required String eventId,
    required String invitationId,
    String? name,
    int expiryDays = 7,
  }) async {
    regenerateCalls += 1;
    return regenerated ?? created!;
  }

  @override
  Future<StaffInvitation> create({
    required String eventId,
    required String name,
    Iterable<String>? permissions,
    int expiryDays = 7,
  }) async {
    createCalls += 1;
    lastName = name;
    lastPermissions = permissions;
    if (createError != null) throw createError!;
    return created!;
  }
}

StaffInvitation _invitation({
  String name = 'Budi Santoso',
  String? accessCode = 'ABCD-2345',
}) => StaffInvitation(
  id: 'inv-1',
  staffName: name,
  status: 'PENDING',
  permissions: const <String>['VIEW_EVENT', 'SCAN_TICKET'],
  accessCode: accessCode,
  inviteUrl: 'http://localhost:3000/staff-access/inv-1',
  expiresAt: DateTime(2026, 12, 7),
);

Widget _app({
  required _FakeMembershipService membership,
  required _FakeInvitationService invitation,
  String eventId = 'evt-1',
}) => MaterialApp(
  home: TeamManagementScreen(
    eventId: eventId,
    eventTitle: 'Konser Musik 2026',
    membershipService: membership,
    invitationService: invitation,
  ),
);

void main() {
  group('Halaman Tambahkan Staf (Organizer)', () {
    testWidgets('menampilkan aksi "Tambahkan Staf" pada halaman staf', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: _FakeInvitationService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-add-fab')), findsOneWidget);
      expect(find.text('Tambahkan Staf'), findsOneWidget);
      expect(
        find.text('Belum ada staf yang ditambahkan pada event ini.'),
        findsOneWidget,
      );
    });

    testWidgets('nama staf ditambahkan dan kode akses ditampilkan', (
      tester,
    ) async {
      final invitationService = _FakeInvitationService(created: _invitation());
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: invitationService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('staff-add-fab')));
      await tester.pumpAndSettle();

      // Judul dialog memakai kata "Tambahkan Staf", bukan "Undang Staf".
      expect(find.text('Tambahkan Staf'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('staff-invitation-name')),
        '  Budi Santoso  ',
      );
      await tester.tap(find.byKey(const Key('staff-invitation-submit')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(invitationService.createCalls, 1);
      expect(invitationService.lastName, 'Budi Santoso');
      expect(
        find.byKey(const Key('staff-invitation-result-dialog')),
        findsOneWidget,
      );
      expect(find.text('Staf Ditambahkan'), findsOneWidget);
      expect(
        find.byKey(const Key('staff-invitation-result-code')),
        findsOneWidget,
      );
      expect(find.text('ABCD-2345'), findsOneWidget);
    });

    testWidgets(
      'kegagalan server ditampilkan di dialog dan input tidak hilang',
      (tester) async {
        final invitationService = _FakeInvitationService(
          createError: const NetworkException(
            'Fitur staf belum siap di server: skema database undangan staf '
            'belum dimigrasikan.',
            statusCode: 424,
          ),
        );
        await tester.pumpWidget(
          _app(
            membership: _FakeMembershipService(),
            invitation: invitationService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('staff-add-fab')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('staff-invitation-name')),
          'Siti Rahma',
        );
        await tester.tap(find.byKey(const Key('staff-invitation-submit')));
        await tester.pumpAndSettle();

        expect(invitationService.createCalls, 1);
        expect(
          find.byKey(const Key('staff-invitation-submit-error')),
          findsOneWidget,
        );
        expect(find.textContaining('belum dimigrasikan'), findsOneWidget);
        // Dialog tetap terbuka dan nama tidak perlu diketik ulang.
        expect(
          find.byKey(const Key('staff-invitation-submit')),
          findsOneWidget,
        );
        expect(find.text('Siti Rahma'), findsOneWidget);
      },
    );

    testWidgets('kode akses staf yang sudah ditambahkan tampil di kartu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: _FakeInvitationService(
            invitations: <StaffInvitation>[_invitation()],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-invitation-inv-1')), findsOneWidget);
      final code = tester.widget<SelectableText>(
        find.byKey(const Key('staff-invitation-code-inv-1')),
      );
      expect(code.data, 'ABCD-2345');
    });

    testWidgets('Buat Kode Baru menampilkan kode akses pengganti', (
      tester,
    ) async {
      final invitationService = _FakeInvitationService(
        invitations: <StaffInvitation>[_invitation(accessCode: null)],
        regenerated: _invitation(),
      );
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: invitationService,
        ),
      );
      await tester.pumpAndSettle();

      final regenerateButton = find.byKey(
        const Key('staff-invitation-regenerate-inv-1'),
      );
      await tester.ensureVisible(regenerateButton);
      await tester.tap(regenerateButton);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('staff-invitation-regenerate-confirm')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(invitationService.regenerateCalls, 1);
      expect(
        find.byKey(const Key('staff-invitation-result-dialog')),
        findsOneWidget,
      );
      expect(find.text('ABCD-2345'), findsOneWidget);
    });

    testWidgets('kegagalan memuat daftar staf ditampilkan sebagai banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: _FakeInvitationService(
            listError: const NetworkException(
              'Internal Server Error',
              statusCode: 500,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('staff-invitation-load-error')),
        findsOneWidget,
      );
      expect(find.textContaining('Daftar staf gagal dimuat'), findsOneWidget);
    });

    testWidgets('tanpa eventId, aksi tambah staf tidak ditampilkan', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          membership: _FakeMembershipService(),
          invitation: _FakeInvitationService(),
          eventId: '',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-add-fab')), findsNothing);
      expect(find.textContaining('Event belum dipilih'), findsOneWidget);
    });
  });
}
