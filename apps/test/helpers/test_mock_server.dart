import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/services/mock/mock_attendee_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';

class TestMockServer {
  TestMockServer._();

  static TestMockServer? _instance;

  static List<Map<String, dynamic>> _reports = _initialReports();

  static List<Map<String, dynamic>> _initialReports() => [
        {
          'id': 'rpt-001',
          'user_id': 'usr-part-002',
          'contact_email': 'dewi.lestari@example.com',
          'order_reference': 'ORD-2026-9901',
          'category': 'PAYMENT',
          'subject': 'Kendala verifikasi pembayaran QRIS tiket festival',
          'description':
              'Saya sudah mentransfer nominal tiket via QRIS simulasi namun status pembayaran belum berubah menjadi Paid.',
          'status': 'in_progress',
          'priority': 'high',
          'ticket_number': 'RPT-2026-001',
          'status_token': 'st-token-dewi-9901',
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 4))
              .toIso8601String(),
          'updated_at': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'handled_by': 'Admin Platform',
          'replies': <Map<String, dynamic>>[
            {
              'id': 'rep-001-1',
              'report_id': 'rpt-001',
              'sender_name': 'Dewi Lestari',
              'sender_role': 'Pelapor',
              'message':
                  'Bukti transfer QRIS nomor ref 9988221 sudah berhasil terpotong dari saldo.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 4))
                  .toIso8601String(),
            },
          ],
          'internal_notes': <Map<String, dynamic>>[],
          'activities': <Map<String, dynamic>>[
            {
              'id': 'act-001-1',
              'report_id': 'rpt-001',
              'action': 'Laporan Dibuat',
              'note': 'Laporan dibuat dari formulir bantuan',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 4))
                  .toIso8601String(),
            },
          ],
        },
        {
          'id': 'rpt-002',
          'user_id': 'usr-part-001',
          'contact_email': 'budi.santoso@example.com',
          'order_reference': 'ORD-2026-9902',
          'category': 'TICKET',
          'subject':
              'Tiket tidak muncul di menu Tiket Saya setelah sukses bayar',
          'description':
              'Status pesanan sudah Paid tapi tab tiket masih kosong. Mohon bantuan sinkronisasi.',
          'status': 'resolved',
          'priority': 'medium',
          'ticket_number': 'RPT-2026-002',
          'status_token': 'st-token-budi-9902',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'updated_at': DateTime.now()
              .subtract(const Duration(hours: 12))
              .toIso8601String(),
          'handled_by': 'Admin Platform',
          'replies': <Map<String, dynamic>>[
            {
              'id': 'rep-002-1',
              'report_id': 'rpt-002',
              'sender_name': 'Admin Platform',
              'sender_role': 'Admin Platform',
              'message':
                  'Tiket sudah kami kirimkan ulang dalam format PDF cadangan ke email terdaftar.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 12))
                  .toIso8601String(),
            }
          ],
          'internal_notes': <Map<String, dynamic>>[
            {
              'id': 'not-002-1',
              'report_id': 'rpt-002',
              'author_name': 'Admin Platform',
              'note':
                  'Peserta telah berhasil check-in secara manual di gate 2.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 12))
                  .toIso8601String(),
            }
          ],
          'activities': <Map<String, dynamic>>[
            {
              'id': 'act-002-1',
              'report_id': 'rpt-002',
              'action': 'Laporan Dibuat',
              'note': 'Laporan diterima sistem',
              'created_at': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
          ],
        },
        {
          'id': 'rpt-003',
          'user_id': null,
          'contact_email': 'tamu.event@example.com',
          'order_reference': 'ORD-2026-9903',
          'category': 'REGISTRATION',
          'subject': 'Koreksi penulisan nama peserta sertifikat seminar',
          'description':
              'Ada salah ketik pada penulisan nama peserta sertifikat saat pendaftaran tanpa akun.',
          'status': 'open',
          'priority': 'low',
          'ticket_number': 'RPT-2026-003',
          'status_token': 'st-token-guest-9903',
          'created_at': DateTime.now()
              .subtract(const Duration(minutes: 50))
              .toIso8601String(),
          'replies': <Map<String, dynamic>>[],
          'internal_notes': <Map<String, dynamic>>[],
          'activities': <Map<String, dynamic>>[
            {
              'id': 'act-003-1',
              'report_id': 'rpt-003',
              'action': 'Laporan Dibuat',
              'note': 'Laporan dari tamu belum diverifikasi',
              'created_at': DateTime.now()
                  .subtract(const Duration(minutes: 50))
                  .toIso8601String(),
            },
          ],
        },
        {
          'id': 'cmp-001',
          'user_id': 'org-001',
          'contact_email': 'organizer@techsummit.id',
          'order_reference': '',
          'category': 'EVENT',
          'subject':
              'Permohonan percepatan review event Tech Innovation Summit',
          'description':
              'Event kami telah diajukan 2 hari lalu namun status masih pending review. Mohon bantuan konfirmasi dokumen perizinan tempat acara.',
          'status': 'in_progress',
          'priority': 'urgent',
          'ticket_number': 'RPT-ORG-2026-001',
          'status_token': 'tok-org-alpha-991',
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 24))
              .toIso8601String(),
          'updated_at': DateTime.now()
              .subtract(const Duration(hours: 6))
              .toIso8601String(),
          'handled_by': 'Admin Platform',
          'replies': <Map<String, dynamic>>[
            {
              'id': 'rep-cmp1-1',
              'report_id': 'cmp-001',
              'sender_name': 'Penyelenggara',
              'sender_role': 'Penyelenggara',
              'message':
                  'Halo admin, tiket acara kami sudah mulai dipromosikan, mohon bantuannya untuk peninjauan.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 24))
                  .toIso8601String(),
            },
          ],
          'internal_notes': <Map<String, dynamic>>[
            {
              'id': 'not-cmp1-1',
              'report_id': 'cmp-001',
              'author_name': 'Admin Platform',
              'note':
                  'Catatan internal: Penyelenggara sudah verified, dokumen venue valid.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 6))
                  .toIso8601String(),
            }
          ],
          'activities': <Map<String, dynamic>>[
            {
              'id': 'act-cmp1-1',
              'report_id': 'cmp-001',
              'action': 'Laporan Dibuat',
              'note': 'Keluhan diajukan oleh penyelenggara',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 24))
                  .toIso8601String(),
            },
          ],
        },
        {
          'id': 'rpt-005',
          'user_id': 'usr-part-003',
          'contact_email': 'siti.nur@example.com',
          'order_reference': 'ORD-2026-9905',
          'category': 'SCANNER',
          'subject': 'Gagal scan tiket pada pintu masuk VIP',
          'description':
              'Staf di pintu masuk menginformasikan tiket sudah expired padahal event baru dimulai.',
          'status': 'waiting_for_user',
          'priority': 'high',
          'ticket_number': 'RPT-2026-005',
          'status_token': 'st-token-siti-9905',
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 8))
              .toIso8601String(),
          'updated_at': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
          'handled_by': 'Admin Platform',
          'replies': <Map<String, dynamic>>[
            {
              'id': 'rep-005-1',
              'report_id': 'rpt-005',
              'sender_name': 'Admin Platform',
              'sender_role': 'Admin Platform',
              'message':
                  'Mohon kirimkan tangkapan layar e-tiket dan kode gate yang dimasuki.',
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 3))
                  .toIso8601String(),
            },
          ],
          'internal_notes': <Map<String, dynamic>>[],
          'activities': <Map<String, dynamic>>[],
        },
      ];

  static Future<TestMockServer> start() async {
    if (_instance != null) return _instance!;

    TestWidgetsFlutterBinding.ensureInitialized();
    _mockSecureStorage();

    final mockServer = TestMockServer._();
    _instance = mockServer;

    HttpOverrides.global = _ForwardingHttpOverrides();
    return mockServer;
  }

  static void attachHttpOverrides() {
    _mockSecureStorage();
    HttpOverrides.global = _ForwardingHttpOverrides();
  }

  static void resetReports() {
    _reports = _initialReports();
  }

  static void _mockSecureStorage() {
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  }

  Future<void> stop() async {
    _instance = null;
  }

  static Future<Map<String, dynamic>> _respond(
    String method,
    Uri uri,
    String bodyString,
  ) async {
    final path = uri.path;
    Map<String, dynamic> body = {};
    if (bodyString.isNotEmpty) {
      try {
        body = jsonDecode(bodyString) as Map<String, dynamic>;
      } catch (_) {}
    }

    final repo = MockAttendeeRepository.instance;
    final orgRepo = MockOrganizerEventRepository.shared();

    // Routing
    if (path == '/api/events/mine') {
      final events = await orgRepo.listEvents(ownerId: 'org-001');
      return {
        'success': true,
        'events': events.map((e) => e.toJson()).toList(),
      };
    } else if (path.startsWith('/api/events/public')) {
      final query = uri.queryParameters;
      final events = repo.getEvents(
        query: query['q'] ?? query['search'],
        category: query['category'],
      );
      return {
        'success': true,
        'events': events.map((e) => e.toJson()).toList(),
      };
    } else if (path.startsWith('/api/events/') &&
        path.endsWith('/ticket-types')) {
      final eventId = path.split('/')[3];
      var types = repo.getTicketTypesByEventId(eventId);
      if (types.isEmpty) {
        try {
          types = await orgRepo.listTicketTypes(
            ownerId: 'org-001',
            eventId: eventId,
          );
        } catch (_) {}
      }
      final list = types.map((t) => t.toJson()).toList();
      return {
        'success': true,
        'ticket_types': list,
        'ticketTypes': list,
      };
    } else if (path.startsWith('/api/events/') && path.endsWith('/summary')) {
      final eventId = path.split('/')[3];
      return {
        'success': true,
        'summary': {
          'event_id': eventId,
          'status': 'APPROVED',
          'tickets_sold': 50,
          'tickets_remaining': 50,
          'pending_orders': 2,
          'participants': 48,
          'checked_in': 20,
          'gross_sales': 2500000.0,
        },
      };
    } else if (path.startsWith('/api/events/') && path.endsWith('/sales')) {
      return {
        'success': true,
        'points': [
          {
            'date': DateTime.now().toIso8601String(),
            'tickets': 10,
            'check_ins': 5,
          }
        ],
      };
    } else if (path == '/api/organizer/events/summaries') {
      return {
        'success': true,
        'summaries': [
          {
            'event_id': 'evt-1001',
            'status': 'APPROVED',
            'tickets_sold': 50,
            'tickets_remaining': 50,
            'pending_orders': 2,
            'participants': 48,
            'checked_in': 20,
            'gross_sales': 2500000.0,
          }
        ],
      };
    } else if (path == '/api/organizer/overview') {
      return {
        'success': true,
        'overview': {
          'counts': {
            'draft': 0,
            'pending': 0,
            'revision': 0,
            'published': 1,
            'rejected': 0,
            'suspended': 0,
          },
          'recent_events': [],
        },
      };
    } else if (path.startsWith('/api/events/')) {
      final id = path.split('/').last;
      dynamic event;
      try {
        event = repo.getEventById(id);
      } catch (_) {
        event = await orgRepo.getEvent(ownerId: 'org-001', eventId: id);
      }
      return {
        'success': true,
        'event': event.toJson(),
      };
    } else if (path == '/api/orders' && method == 'POST') {
      final items = (body['items'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as int),
      );
      final order = repo.createOrder(
        eventId: body['event_id'] as String? ?? '',
        attendeeName: body['attendee_name'] as String? ?? 'Peserta',
        attendeeEmail: body['attendee_email'] as String? ?? 'peserta@test.com',
        attendeePhone: body['attendee_phone'] as String?,
        selectedTicketQuantities: items,
      );
      return {
        'success': true,
        'order': order.toJson(),
        'order_access_token': 'test-access-token',
      };
    } else if (path.startsWith('/api/orders/') && method == 'GET') {
      final id = path.split('/').last;
      final order = repo.getOrderById(id);
      return {
        'success': true,
        'order': order.toJson(),
      };
    } else if (path == '/api/payments/simulate' && method == 'POST') {
      final orderId = body['order_id'] as String? ?? '';
      final success = body['simulate_success'] as bool? ?? true;
      dynamic payment;
      if (orderId.isNotEmpty) {
        payment = repo.simulatePayment(
          orderId: orderId,
          virtualAccountNumber: '88092812345678',
          simulateSuccess: success,
        );
      }
      return {
        'success': true,
        'status': success ? 'paid' : 'failed',
        'order_id': orderId,
        if (payment != null) 'payment': payment.toJson(),
      };
    } else if ((path == '/api/tickets' || path == '/api/tickets/my-tickets') &&
        method == 'GET') {
      final tickets = repo.getTickets();
      return {
        'success': true,
        'tickets': tickets.map((t) => t.toJson()).toList(),
      };
    } else if (path.startsWith('/api/tickets/') && method == 'GET') {
      final id = path.split('/').last;
      final ticket = repo.getTicketById(id);
      return {
        'success': true,
        'ticket': ticket.toJson(),
      };
    } else if (path.startsWith('/api/ticket-types/') && method == 'GET') {
      final id = path.split('/').last;
      final ticketType = repo.getTicketTypeById(id);
      return {
        'success': true,
        'ticket_type': ticketType.toJson(),
      };
    } else if (path.startsWith('/api/organizer/events')) {
      final events = await orgRepo.listEvents(ownerId: 'org-001');
      return {'success': true, 'events': events.map((e) => e.toJson()).toList()};
    } else if (path.startsWith('/api/support-reports')) {
      if (method == 'GET') {
        if (path == '/api/support-reports') {
          final query = uri.queryParameters;
          var list = List<Map<String, dynamic>>.from(_reports);
          final status = query['status'];
          if (status != null && status.isNotEmpty && status != 'all') {
            list = list
                .where((r) =>
                    r['status']?.toString().toLowerCase() ==
                    status.toLowerCase())
                .toList();
          }
          final category = query['category'];
          if (category != null && category.isNotEmpty && category != 'all') {
            list = list
                .where((r) =>
                    r['category']?.toString().toLowerCase() ==
                    category.toLowerCase())
                .toList();
          }
          final priority = query['priority'];
          if (priority != null && priority.isNotEmpty && priority != 'all') {
            list = list
                .where((r) =>
                    r['priority']?.toString().toLowerCase() ==
                    priority.toLowerCase())
                .toList();
          }
          final search = query['search'];
          if (search != null && search.trim().isNotEmpty) {
            final term = search.trim().toLowerCase();
            list = list.where((r) {
              return (r['ticket_number']
                          ?.toString()
                          .toLowerCase()
                          .contains(term) ??
                      false) ||
                  (r['description']
                          ?.toString()
                          .toLowerCase()
                          .contains(term) ??
                      false) ||
                  (r['subject']?.toString().toLowerCase().contains(term) ??
                      false) ||
                  (r['contact_email']
                          ?.toString()
                          .toLowerCase()
                          .contains(term) ??
                      false) ||
                  (r['order_reference']
                          ?.toString()
                          .toLowerCase()
                          .contains(term) ??
                      false);
            }).toList();
          }
          return {'success': true, 'data': list};
        } else {
          final id = path.split('/').last;
          final report = _reports.firstWhere(
            (r) =>
                r['id'] == id ||
                r['ticket_number']?.toString().toUpperCase() ==
                    id.toUpperCase(),
            orElse: () => _reports.first,
          );
          return {
            'success': true,
            ...report,
            'data': report,
            'report': report,
          };
        }
      } else if (method == 'POST') {
        if (path.endsWith('/reply')) {
          final segments = path.split('/');
          final id = segments[segments.length - 2];
          final report = _reports.firstWhere(
            (r) => r['id'] == id,
            orElse: () => _reports.first,
          );
          final replies = List<Map<String, dynamic>>.from(
              report['replies'] as List? ?? []);
          final newReply = {
            'id': 'rep-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'sender_name': body['sender_name'] ?? 'Admin Platform',
            'sender_role': body['sender_role'] ?? 'Admin Platform',
            'message': body['message'] ?? '',
            'created_at': DateTime.now().toIso8601String(),
          };
          replies.add(newReply);
          report['replies'] = replies;
          final activities = List<Map<String, dynamic>>.from(
              report['activities'] as List? ?? []);
          activities.insert(0, {
            'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'staff_name': body['sender_name'] ?? 'Admin Platform',
            'action': 'Balasan Terkirim',
            'note': 'Balasan publik dikirim kepada pelapor',
            'created_at': DateTime.now().toIso8601String(),
          });
          report['activities'] = activities;
          return {'success': true, ...report};
        } else if (path.endsWith('/internal-note') ||
            path.endsWith('/internal-notes')) {
          final segments = path.split('/');
          final id = segments[segments.length - 2];
          final report = _reports.firstWhere(
            (r) => r['id'] == id,
            orElse: () => _reports.first,
          );
          final notes = List<Map<String, dynamic>>.from(
              report['internal_notes'] as List? ?? []);
          notes.add({
            'id': 'not-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'author_name': body['author_name'] ?? 'Admin Platform',
            'note': body['note'] ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });
          report['internal_notes'] = notes;
          final activities = List<Map<String, dynamic>>.from(
              report['activities'] as List? ?? []);
          activities.insert(0, {
            'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'staff_name': body['author_name'] ?? 'Admin Platform',
            'action': 'Catatan Internal Ditambahkan',
            'note': 'Catatan internal ditambahkan',
            'created_at': DateTime.now().toIso8601String(),
          });
          report['activities'] = activities;
          return {'success': true, ...report};
        } else if (path.endsWith('/status')) {
          final segments = path.split('/');
          final id = segments[segments.length - 2];
          final report = _reports.firstWhere(
            (r) => r['id'] == id,
            orElse: () => _reports.first,
          );
          final status = body['status'] ?? 'open';
          report['status'] = status;
          final activities = List<Map<String, dynamic>>.from(
              report['activities'] as List? ?? []);
          activities.insert(0, {
            'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'staff_name': body['handled_by'] ?? 'Admin Platform',
            'action': 'Status Diubah',
            'note': body['note'] ?? 'Status diubah ke $status',
            'created_at': DateTime.now().toIso8601String(),
          });
          report['activities'] = activities;
          return {'success': true, ...report};
        } else if (path.endsWith('/priority')) {
          final segments = path.split('/');
          final id = segments[segments.length - 2];
          final report = _reports.firstWhere(
            (r) => r['id'] == id,
            orElse: () => _reports.first,
          );
          final priority = body['priority'] ?? 'medium';
          report['priority'] = priority;
          final activities = List<Map<String, dynamic>>.from(
              report['activities'] as List? ?? []);
          activities.insert(0, {
            'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
            'report_id': id,
            'staff_name': body['handled_by'] ?? 'Admin Platform',
            'action': 'Prioritas Diubah',
            'note': 'Prioritas diubah ke $priority',
            'created_at': DateTime.now().toIso8601String(),
          });
          report['activities'] = activities;
          return {'success': true, ...report};
        } else {
          final id = 'rpt-${DateTime.now().millisecondsSinceEpoch}';
          final ticketNum = 'RPT-2026-00${_reports.length + 1}';
          final statusToken = 'tok-${DateTime.now().millisecondsSinceEpoch}';
          final newReport = {
            'id': id,
            'user_id': body['user_id'],
            'contact_email': body['contact_email'] ?? 'guest@example.com',
            'order_reference': body['order_reference'] ?? '',
            'category': body['category'] ?? 'OTHER',
            'subject': body['subject'] ?? 'Laporan Baru',
            'description': body['description'] ?? '',
            'status': 'open',
            'priority': body['priority'] ?? 'medium',
            'ticket_number': ticketNum,
            'status_token': statusToken,
            'created_at': DateTime.now().toIso8601String(),
            'replies': <Map<String, dynamic>>[],
            'internal_notes': <Map<String, dynamic>>[],
            'activities': <Map<String, dynamic>>[
              {
                'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
                'report_id': id,
                'action': 'Laporan Dibuat',
                'note': 'Tiket berhasil didaftarkan',
                'created_at': DateTime.now().toIso8601String(),
              }
            ],
          };
          _reports.insert(0, newReport);
          return {'success': true, ...newReport};
        }
      } else if (method == 'PATCH' || method == 'PUT') {
        final segments = path.split('/');
        final action = segments.last;
        final id = segments[segments.length - 2];
        final report = _reports.firstWhere(
          (r) => r['id'] == id,
          orElse: () => _reports.first,
        );
        if (action == 'status') {
          report['status'] = body['status'] ?? 'open';
          return {'success': true, ...report};
        } else if (action == 'priority') {
          report['priority'] = body['priority'] ?? 'medium';
          return {'success': true, ...report};
        }
      }
    } else if (path.startsWith('/api/notifications')) {
      return {
        'success': true,
        'data': [
          {
            'id': 'notif-001',
            'title': 'Event Disetujui',
            'message':
                'Event "Tech Innovation Summit 2026" telah disetujui oleh admin platform dan siap ditayangkan.',
            'type': 'event_approved',
            'is_read': false,
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
          },
          {
            'id': 'notif-002',
            'title': 'Laporan Ditindaklanjuti',
            'message':
                'Laporan kendala RPT-2026-001 telah ditanggapi oleh tim admin support.',
            'type': 'report_update',
            'is_read': false,
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 3))
                .toIso8601String(),
          },
          {
            'id': 'notif-003',
            'title': 'Check-in Offline Tersinkron',
            'message':
                '5 data check-in offline berhasil disinkronkan ke server utama tanpa konflik.',
            'type': 'check_in_sync',
            'is_read': true,
            'created_at': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
          {
            'id': 'notif-004',
            'title': 'Undangan Staf Baru',
            'message':
                'Anda telah ditugaskan sebagai Staf Verifikator QR Code pada Tech Innovation Summit 2026.',
            'type': 'staff_invite',
            'is_read': true,
            'created_at': DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
          },
        ],
      };
    }
    return {'success': true, 'data': {}};
  }
}

class _ForwardingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _ForwardingHttpClient();
  }
}

class _ForwardingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url, TestMockServer._respond);
  }

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {}

  @override
  void addProxyCredentials(String host, int port, String realm,
      HttpClientCredentials credentials) {}

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String? realm)? f) {}

  @override
  set authenticateProxy(
      Future<bool> Function(
              String host, int port, String scheme, String? realm)?
          f) {}

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {}

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {}

  @override
  set keyLog(Function(String line)? callback) {}

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.uri, this._responder);

  @override
  final String method;
  @override
  final Uri uri;
  final Future<Map<String, dynamic>> Function(
      String method, Uri uri, String body) _responder;

  final HttpHeaders _headers = _FakeHttpHeaders();
  final List<int> _bodyBytes = [];
  final Completer<HttpClientResponse> _completer =
      Completer<HttpClientResponse>();

  @override
  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) => _bodyBytes.addAll(data);

  @override
  Future addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  void write(Object? obj) {
    if (obj != null) _bodyBytes.addAll(utf8.encode(obj.toString()));
  }

  @override
  Future<HttpClientResponse> get done => _completer.future;

  @override
  Future<HttpClientResponse> close() async {
    final bodyStr = utf8.decode(_bodyBytes, allowMalformed: true);
    final jsonResponse = await _responder(method, uri, bodyStr);
    final responseBytes = utf8.encode(jsonEncode(jsonResponse));
    final response = _FakeHttpClientResponse(responseBytes);
    if (!_completer.isCompleted) {
      _completer.complete(response);
    }
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }

  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;

  @override
  ContentType? get contentType => ContentType.json;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
