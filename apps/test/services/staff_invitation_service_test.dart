import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/services/api/api_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/staff_invitation_service.dart';

/// ApiService palsu: merekam path/body dan mengembalikan respons yang diatur.
class _FakeApiService extends ApiService {
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
  Map<String, dynamic> response = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(<String, dynamic>{'method': 'GET', 'path': path});
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(<String, dynamic>{'method': 'POST', 'path': path, 'body': body});
    return response;
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    calls.add(<String, dynamic>{'method': 'DELETE', 'path': path});
    return response;
  }
}

Map<String, dynamic> _invitationJson({
  String id = 'inv-1',
  String name = 'Budi Santoso',
  String status = 'PENDING',
  String? code = 'ABCD-2345',
}) => <String, dynamic>{
  'id': id,
  'staff_name': name,
  'status': status,
  'permissions': <String>['VIEW_EVENT', 'SCAN_TICKET'],
  'access_code': code,
  'invite_url': 'http://localhost:3000/staff-access/$id',
  'expires_at': '2026-12-07T10:00:00.000Z',
  'accepted_at': null,
};

void main() {
  group('StaffInvitationService', () {
    test('membuat undangan berdasarkan nama ke endpoint yang benar', () async {
      final api = _FakeApiService()
        ..response = <String, dynamic>{'invitation': _invitationJson()};
      final service = StaffInvitationService(api: api);

      final invitation = await service.create(
        eventId: 'evt-1',
        name: '  Budi Santoso  ',
        permissions: const <String>['SCAN_TICKET'],
      );

      expect(api.calls.single['method'], 'POST');
      expect(api.calls.single['path'], '/events/evt-1/staff-invitations');
      final body = api.calls.single['body'] as Map<String, dynamic>;
      expect(body['name'], 'Budi Santoso');
      expect(body['permissions'], <String>['SCAN_TICKET']);

      expect(invitation.staffName, 'Budi Santoso');
      expect(invitation.accessCode, 'ABCD-2345');
      expect(invitation.inviteUrl, contains('/staff-access/inv-1'));
      expect(invitation.isPending, isTrue);
      expect(invitation.isActive, isTrue);
    });

    test('daftar undangan memuat kode akses dan status', () async {
      final api = _FakeApiService()
        ..response = <String, dynamic>{
          'invitations': <dynamic>[
            _invitationJson(),
            _invitationJson(id: 'inv-2', status: 'REVOKED', code: null),
          ],
        };
      final service = StaffInvitationService(api: api);

      final list = await service.list('evt-1');

      expect(api.calls.single['path'], '/events/evt-1/staff-invitations');
      expect(list.length, 2);
      expect(list.first.isActive, isTrue);
      expect(list.last.isRevoked, isTrue);
      expect(list.last.isActive, isFalse);
      expect(list.last.accessCode, isNull);
    });

    test('regenerate dan revoke memakai path undangan yang tepat', () async {
      final api = _FakeApiService()
        ..response = <String, dynamic>{'invitation': _invitationJson()};
      final service = StaffInvitationService(api: api);

      await service.regenerate(eventId: 'evt-1', invitationId: 'inv-1');
      await service.revoke(eventId: 'evt-1', invitationId: 'inv-1');

      expect(
        api.calls[0]['path'],
        '/events/evt-1/staff-invitations/inv-1/regenerate',
      );
      expect(api.calls[1]['method'], 'DELETE');
      expect(api.calls[1]['path'], '/events/evt-1/staff-invitations/inv-1');
    });
  });
}
