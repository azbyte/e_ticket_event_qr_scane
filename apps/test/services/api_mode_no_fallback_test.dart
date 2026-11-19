import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/core/errors/app_exception.dart';
import 'package:e_ticket_event_qr_scane/core/network/api_client.dart';
import 'package:e_ticket_event_qr_scane/core/services/order_access_token_store.dart';
import 'package:e_ticket_event_qr_scane/services/api/api_service.dart';
import 'package:e_ticket_event_qr_scane/services/order/order_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/api_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_exceptions.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_repository_factory.dart';
import 'package:e_ticket_event_qr_scane/services/payment/payment_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_type_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingApiClient implements ApiClient {
  _FailingApiClient(this.failure);

  final AppException failure;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => throw failure;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => throw failure;

  @override
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async =>
      throw failure;

  @override
  Future<Map<String, dynamic>> delete(String path) async => throw failure;
}

class _ListResponseApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => {
    'success': true,
    'data': [
      {'id': 'ticket-1'},
    ],
  };

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => {};

  @override
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async => {};

  @override
  Future<Map<String, dynamic>> delete(String path) async => {};
}

class _RecordingApiClient implements ApiClient {
  _RecordingApiClient(this.response);

  final Map<String, dynamic> response;
  String? path;
  dynamic requestBody;
  Map<String, dynamic>? requestQuery;
  Map<String, String>? requestHeaders;

  @override
  Future<Map<String, dynamic>> get(
    String requestPath, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    path = requestPath;
    requestQuery = query;
    requestHeaders = headers;
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(
    String requestPath, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    path = requestPath;
    requestBody = body;
    requestHeaders = headers;
    return response;
  }

  @override
  Future<Map<String, dynamic>> put(String requestPath, {dynamic body}) async {
    path = requestPath;
    requestBody = body;
    return response;
  }

  @override
  Future<Map<String, dynamic>> delete(String requestPath) async {
    path = requestPath;
    return response;
  }
}

class _EmptyOrderAccessTokenStore implements OrderAccessTokenStore {
  @override
  Future<String?> read(String orderId) async => null;

  @override
  Future<void> save(String orderId, String token) async {}
}

class _MemoryOrderAccessTokenStore implements OrderAccessTokenStore {
  final Map<String, String> tokens = {};

  @override
  Future<String?> read(String orderId) async => tokens[orderId];

  @override
  Future<void> save(String orderId, String token) async {
    tokens[orderId] = token;
  }
}

void main() {
  group(
    'API mode does not fall back to mock data',
    skip: AppConfig.mockMode,
    () {
      final failure = NetworkException('API endpoint unavailable');
      final api = ApiService(client: _FailingApiClient(failure));

      test('organizer event repository defaults to API mode', () {
        expect(
          createOrganizerEventRepository(),
          isA<ApiOrganizerEventRepository>(),
        );
      });

      test('ticket listing propagates API errors', () async {
        await expectLater(
          TicketService(api: api).listTickets(),
          throwsA(same(failure)),
        );
      });

      test('ticket type lookup propagates API errors', () async {
        await expectLater(
          TicketTypeService(api: api).getTicketTypesByEventId('event-1'),
          throwsA(same(failure)),
        );
      });

      test('order creation propagates API errors', () async {
        await expectLater(
          OrderService(api: api).createOrder(const {'event_id': 'event-1'}),
          throwsA(same(failure)),
        );
      });

      test('payment simulation propagates API errors', () async {
        await expectLater(
          PaymentService(
            api: api,
            orderTokens: _EmptyOrderAccessTokenStore(),
          ).simulatePayment(
            orderId: 'order-1',
            virtualAccountNumber: '0000000000',
          ),
          throwsA(same(failure)),
        );
      });

      test('order creation stores the guest access token securely', () async {
        final client = _RecordingApiClient({
          'success': true,
          'order': {'id': 'order-1'},
          'order_access_token': 'opaque-guest-token',
        });
        final tokenStore = _MemoryOrderAccessTokenStore();

        final order = await OrderService(
          api: ApiService(client: client),
          orderTokens: tokenStore,
        ).createOrder(const {'event_id': 'event-1'});

        expect(order['id'], 'order-1');
        expect(tokenStore.tokens['order-1'], 'opaque-guest-token');
      });

      test(
        'guest payment and ticket reads send the stored order token',
        () async {
          final tokenStore = _MemoryOrderAccessTokenStore()
            ..tokens['order-1'] = 'opaque-guest-token';
          final paymentClient = _RecordingApiClient({
            'success': true,
            'payment': {'id': 'payment-1'},
          });
          final payment = await PaymentService(
            api: ApiService(client: paymentClient),
            orderTokens: tokenStore,
          ).getPayment('order-1');

          expect(payment['id'], 'payment-1');
          expect(paymentClient.requestQuery, isNull);
          expect(paymentClient.requestHeaders, {
            'X-Order-Access-Token': 'opaque-guest-token',
          });

          final ticketClient = _RecordingApiClient({
            'success': true,
            'tickets': [
              {'id': 'ticket-1'},
            ],
          });
          final tickets = await TicketService(
            api: ApiService(client: ticketClient),
            orderTokens: tokenStore,
          ).listTickets(query: {'order_id': 'order-1'});

          expect(tickets.single['id'], 'ticket-1');
          expect(ticketClient.requestQuery, {'order_id': 'order-1'});
          expect(ticketClient.requestHeaders, {
            'X-Order-Access-Token': 'opaque-guest-token',
          });
        },
      );

      test('API facade preserves list response envelopes', () async {
        final response = await ApiService(client: _ListResponseApiClient())
            .get('/tickets');

        expect(response['data'], isA<List<Map<String, dynamic>>>());
      });

      test(
        'organizer event repository reads persisted events from the API',
        () async {
          final client = _RecordingApiClient({
            'success': true,
            'events': [
              {
                'id': 'event-1',
                'organizer_id': 'user-1',
                'title': 'Event API',
                'start_date_time': '2026-12-01T10:00:00.000Z',
                'end_date_time': '2026-12-01T12:00:00.000Z',
                'event_type': 'offline',
                'status': 'draft',
                'is_public': false,
              },
            ],
          });
          final repository = ApiOrganizerEventRepository(
            api: ApiService(client: client),
          );

          final events = await repository.listEvents(ownerId: 'user-1');

          expect(client.path, '/events/mine');
          expect(events.single.title, 'Event API');
          expect(events.single.id, 'event-1');
        },
      );

      test('organizer event mutations preserve server errors', () async {
        final repository = ApiOrganizerEventRepository(
          api: ApiService(client: _FailingApiClient(failure)),
        );

        await expectLater(
          repository.listEvents(ownerId: 'user-1'),
          throwsA(isA<OrganizerEventException>()),
        );
      });

      test('event creation sends the validated form to the backend', () async {
        final client = _RecordingApiClient({
          'success': true,
          'event': {
            'id': 'event-2',
            'organizer_id': 'user-1',
            'title': 'Event API Baru',
            'start_date_time': '2026-12-01T10:00:00.000Z',
            'end_date_time': '2026-12-01T12:00:00.000Z',
            'event_type': 'offline',
            'status': 'draft',
            'is_public': false,
          },
        });
        final repository = ApiOrganizerEventRepository(
          api: ApiService(client: client),
        );
        final draft = OrganizerEventDraft(
          title: 'Event API Baru',
          category: 'Teknologi',
          description: '',
          organizerName: 'Organizer',
          contactInfo: 'organizer@example.test',
          startDateTime: DateTime.utc(2026, 12, 1, 10),
          endDateTime: DateTime.utc(2026, 12, 1, 12),
          timeZone: 'Asia/Jakarta',
          format: 'offline',
          location: 'Jakarta',
        );

        final event = await repository.createEvent(
          ownerId: 'user-1',
          draft: draft,
        );

        expect(client.path, '/events');
        expect(client.requestBody['event_date'], '2026-12-01T10:00:00.000Z');
        expect(client.requestBody['event_format'], 'OFFLINE');
        expect(event.id, 'event-2');
      });
    },
  );
}
