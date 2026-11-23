import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/core/errors/app_exception.dart';
import 'package:e_ticket_event_qr_scane/core/network/api_client.dart';
import 'package:e_ticket_event_qr_scane/core/services/order_access_token_store.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/models/order/order_model.dart';
import 'package:e_ticket_event_qr_scane/models/payment/payment_model.dart';
import 'package:e_ticket_event_qr_scane/models/ticket/ticket_model.dart';
import 'package:e_ticket_event_qr_scane/providers/order_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/payment_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/ticket_provider.dart';
import 'package:e_ticket_event_qr_scane/services/api/api_service.dart';
import 'package:e_ticket_event_qr_scane/services/order/order_service.dart';
import 'package:e_ticket_event_qr_scane/services/payment/payment_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_type_service.dart';

/// Test integrasi Tahap 1 sisi klien (integrator/Developer 4).
///
/// Fixture JSON meniru bentuk response backend setelah serialisasi
/// (`serializeEvent`, `toTicketTypeDto`, `serializeOrder`, `serializePayment`,
/// presentasi tiket). Tujuannya memastikan rantai event -> kategori tiket ->
/// order guest -> pembayaran -> tiket memakai service, provider, dan model yang
/// sama dengan aplikasi, tanpa HTTP nyata dan tanpa fallback mock.
const String _eventId = '44444444-4444-4444-8444-444444444444';
const String _ticketTypeId = '55555555-5555-4555-8555-555555555555';
const String _orderId = '66666666-6666-4666-8666-666666666666';
const String _paymentId = '77777777-7777-4777-8777-777777777777';
const String _ticketId = '88888888-8888-4888-8888-888888888888';
const String _organizerId = '11111111-1111-4111-8111-111111111111';
const String _accessToken = 'guest-order-access-token-stage1-opaque-value';
const String _qrToken = 'qr-ticket-token-stage1-opaque-value-0123456789';

const Map<String, dynamic> _eventJson = {
  'id': _eventId,
  'organizer_id': _organizerId,
  'title': 'Konser Uji Integrasi',
  'description': 'Event sintetis untuk test integrasi',
  'poster_url': null,
  'category': 'Teknologi',
  'start_date_time': '2026-12-01T10:00:00.000Z',
  'end_date_time': '2026-12-01T13:00:00.000Z',
  'time_zone': 'Asia/Jakarta',
  'location': 'Auditorium Uji',
  'online_url': null,
  'event_type': 'offline',
  'contact_info': 'organizer@example.test',
  'organizer_name': 'Organizer Uji',
  'public_info': null,
  'attendee_fields': ['name', 'email', 'phone'],
  'status': 'published',
  'review_note': null,
  'submitted_at': null,
  'is_public': true,
  'created_at': '2026-11-20T08:00:00.000Z',
  'updated_at': '2026-11-20T08:00:00.000Z',
};

const Map<String, dynamic> _ticketTypeJson = {
  'id': _ticketTypeId,
  'event_id': _eventId,
  'name': 'Reguler',
  'description': null,
  'price': 25000,
  'quota': 100,
  'sold': 40,
  'held': 10,
  'max_per_order': 1,
  'sales_start': null,
  'sales_end': null,
  'is_active': true,
  'remaining_quota': 50,
  'is_sold_out': false,
  'is_available': true,
  'created_at': '2026-11-20T08:00:00.000Z',
  'updated_at': '2026-11-20T08:00:00.000Z',
};

const Map<String, dynamic> _pendingPaymentJson = {
  'id': _paymentId,
  'order_id': _orderId,
  'method': 'virtual_account',
  'status': 'pending',
  'amount': 30000,
  'payment_reference': 'SIM-ORD-STAGE1-0001',
  'virtual_account_number': '8800112233445566',
  'va_bank': 'VA Simulasi',
  'paid_at': null,
  'expired_at': '2026-11-24T08:00:00.000Z',
  'notes': null,
};

const Map<String, dynamic> _paidPaymentJson = {
  'id': _paymentId,
  'order_id': _orderId,
  'method': 'virtual_account',
  'status': 'paid',
  'amount': 30000,
  'payment_reference': 'SIM-ORD-STAGE1-0001',
  'virtual_account_number': '8800112233445566',
  'va_bank': 'VA Simulasi',
  'paid_at': '2026-11-23T09:00:00.000Z',
  'expired_at': '2026-11-24T08:00:00.000Z',
  'notes': null,
};

const Map<String, dynamic> _orderJson = {
  'id': _orderId,
  'order_number': 'ORD-STAGE1-0001',
  'user_id': null,
  'event_id': _eventId,
  'event_title': 'Konser Uji Integrasi',
  'status': 'pending_payment',
  'total_amount': 25000,
  'service_fee': 5000,
  'grand_total': 30000,
  'items': [
    {
      'id': 'item-1',
      'order_id': _orderId,
      'ticket_type_id': _ticketTypeId,
      'ticket_type_name': 'Reguler',
      'quantity': 1,
      'unit_price': 25000,
      'subtotal': 25000,
    },
  ],
  'expires_at': '2026-11-24T08:00:00.000Z',
  'payment_reference': 'SIM-ORD-STAGE1-0001',
  'created_at': '2026-11-23T08:00:00.000Z',
  'updated_at': '2026-11-23T08:00:00.000Z',
  'payment': _pendingPaymentJson,
};

const Map<String, dynamic> _ticketJson = {
  'id': _ticketId,
  'ticket_code': 'TKT-STAGE1-0001',
  'event_id': _eventId,
  'user_id': null,
  'ticket_type_id': _ticketTypeId,
  'attendee_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'qr_code_data': 'TKT-STAGE1-0001',
  'status': 'valid',
  'purchased_at': '2026-11-23T08:00:00.000Z',
  'issued_at': '2026-11-23T08:00:00.000Z',
  'used_at': null,
  'attendee_name': 'Budi Santoso',
  'attendee_email': 'budi@example.test',
  'attendee_phone': '081200000000',
  'order_id': _orderId,
  'token': _qrToken,
  'events': {
    'id': _eventId,
    'title': 'Konser Uji Integrasi',
    'status': 'PUBLISHED',
    'is_public': true,
  },
};

class _MemoryOrderAccessTokenStore implements OrderAccessTokenStore {
  final Map<String, String> tokens = {};

  @override
  Future<String?> read(String orderId) async => tokens[orderId];

  @override
  Future<void> save(String orderId, String token) async {
    tokens[orderId] = token;
  }
}


class _Stage1ApiClient implements ApiClient {
  final List<String> calls = [];
  final Map<String, Map<String, String>?> headersByCall = {};
  final Map<String, dynamic> bodiesByCall = {};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final call = 'GET $path';
    calls.add(call);
    headersByCall[call] = headers;
    switch (path) {
      case '/events/public':
        return {
          'success': true,
          'count': 1,
          'events': [_eventJson],
        };
      case '/events/$_eventId':
        return {'success': true, 'event': _eventJson};
      case '/events/$_eventId/ticket-types':
        return {
          'success': true,
          'ticketTypes': [_ticketTypeJson],
          'ticket_types': [_ticketTypeJson],
        };
      case '/orders/$_orderId':
        return {'success': true, 'order': _orderJson, 'data': _orderJson};
      case '/payments/$_orderId':
        return {'success': true, 'payment': _pendingPaymentJson};
      case '/tickets/my-tickets':
        return {
          'success': true,
          'count': 1,
          'tickets': [_ticketJson],
        };
    }
    throw NetworkException('Endpoint tak terduga pada test: $path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final call = 'POST $path';
    calls.add(call);
    headersByCall[call] = headers;
    bodiesByCall[call] = body;
    if (path == '/orders') {
      return {
        'success': true,
        'order': _orderJson,
        'order_access_token': _accessToken,
      };
    }
    if (path == '/payments/simulate') {
      return {
        'success': true,
        'payment': _paidPaymentJson,
        'email_delivery': {
          'configured': true,
          'transport': 'json',
          'results': <Map<String, dynamic>>[],
        },
      };
    }
    throw NetworkException('Endpoint tak terduga pada test: $path');
  }

  @override
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async {
    throw NetworkException('PUT tidak dipakai pada alur Tahap 1: $path');
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    throw NetworkException('DELETE tidak dipakai pada alur Tahap 1: $path');
  }
}

class _FailingOrderApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => throw const NetworkException('API endpoint unavailable');

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => throw const NetworkException('API endpoint unavailable');

  @override
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async =>
      throw const NetworkException('API endpoint unavailable');

  @override
  Future<Map<String, dynamic>> delete(String path) async =>
      throw const NetworkException('API endpoint unavailable');
}


void main() {
  group('Kontrak JSON Tahap 1 (model klien)', () {
    test('EventModel membaca response serializeEvent', () {
      final event = EventModel.fromJson(_eventJson);

      expect(event.id, _eventId);
      expect(event.organizerId, _organizerId);
      expect(event.title, 'Konser Uji Integrasi');
      expect(event.status, 'published');
      expect(event.isPublic, isTrue);
      expect(event.eventType, 'offline');
      expect(event.category, 'Teknologi');
      expect(event.startDateTime, DateTime.utc(2026, 12, 1, 10));
      expect(event.attendeeFields, ['name', 'email', 'phone']);
      expect(event.organizerName, 'Organizer Uji');
    });

    test('TicketTypeModel membaca DTO kategori tiket', () {
      final ticketType = TicketTypeModel.fromJson(_ticketTypeJson);

      expect(ticketType.eventId, _eventId);
      expect(ticketType.price, 25000);
      expect(ticketType.quota, 100);
      expect(ticketType.sold, 40);
      expect(ticketType.held, 10);
      expect(ticketType.remainingQuota, 50);
      expect(ticketType.isSellableAt(DateTime.utc(2026, 11, 23)), isTrue);
    });

    test('OrderModel membaca response serializeOrder', () {
      final order = OrderModel.fromJson(_orderJson);

      expect(order.id, _orderId);
      expect(order.eventTitle, 'Konser Uji Integrasi');
      expect(order.status, 'pending_payment');
      expect(order.isPending, isTrue);
      expect(order.totalAmount, 25000);
      expect(order.serviceFee, 5000);
      expect(order.grandTotal, 30000);
      expect(order.items.single.ticketTypeName, 'Reguler');
      expect(order.items.single.quantity, 1);
      expect(order.paymentReference, 'SIM-ORD-STAGE1-0001');
    });

    test('PaymentModel membaca response serializePayment', () {
      final payment = PaymentModel.fromJson(_pendingPaymentJson);

      expect(payment.orderId, _orderId);
      expect(payment.method, 'virtual_account');
      expect(payment.status, 'pending');
      expect(payment.amount, 30000);
      expect(payment.vaBank, 'VA Simulasi');
      expect(payment.virtualAccountNumber, '8800112233445566');
    });

    test('TicketModel membaca response tiket order', () {
      final ticket = TicketModel.fromJson(_ticketJson);

      expect(ticket.id, _ticketId);
      expect(ticket.orderId, _orderId);
      expect(ticket.eventId, _eventId);
      expect(ticket.ticketTypeId, _ticketTypeId);
      expect(ticket.attendeeName, 'Budi Santoso');
      expect(ticket.attendeeEmail, 'budi@example.test');
      expect(ticket.status, 'valid');
      expect(ticket.isValid, isTrue);
      expect(ticket.token, _qrToken);
    });
  });


  group(
    'Alur guest event -> order -> pembayaran -> tiket',
    skip: AppConfig.mockMode,
    () {
      late _Stage1ApiClient client;
      late _MemoryOrderAccessTokenStore tokens;
      late ApiService api;

      setUp(() {
        client = _Stage1ApiClient();
        tokens = _MemoryOrderAccessTokenStore();
        api = ApiService(client: client);
      });

      test('service memakai endpoint dan header order yang benar', () async {
        final ticketTypes = await TicketTypeService(
          api: api,
        ).getTicketTypesByEventId(_eventId);
        expect(ticketTypes.single.id, _ticketTypeId);
        expect(ticketTypes.single.price, 25000);
        expect(ticketTypes.single.remainingQuota, 50);
        expect(client.calls, contains('GET /events/$_eventId/ticket-types'));

        final orderService = OrderService(api: api, orderTokens: tokens);
        final order = await orderService.createOrder({
          'event_id': _eventId,
          'items': {_ticketTypeId: 1},
          'attendees': [
            {
              'ticket_type_id': _ticketTypeId,
              'name': 'Budi Santoso',
              'email': 'budi@example.test',
            },
          ],
          'idempotency_key': 'stage1-idempotency-key-0001',
        });

        expect(order['id'], _orderId);
        expect(tokens.tokens[_orderId], _accessToken);
        final orderPayload =
            client.bodiesByCall['POST /orders'] as Map<String, dynamic>;
        expect(orderPayload['items'], {_ticketTypeId: 1});
        expect(
          (orderPayload['attendees'] as List).length,
          1,
          reason: 'Tahap 1 hanya mengizinkan satu attendee per order',
        );

        final detail = await orderService.getOrder(_orderId);
        expect(client.headersByCall['GET /orders/$_orderId'], {
          'X-Order-Access-Token': _accessToken,
        });
        expect(OrderModel.fromJson(detail).grandTotal, 30000);

        final paymentService = PaymentService(api: api, orderTokens: tokens);
        final pending = await paymentService.getPayment(_orderId);
        expect(pending['status'], 'pending');
        expect(client.headersByCall['GET /payments/$_orderId'], {
          'X-Order-Access-Token': _accessToken,
        });

        final paid = await paymentService.simulatePayment(
          orderId: _orderId,
          virtualAccountNumber: '8800112233445566',
        );
        expect(paid['status'], 'paid');
        expect(client.headersByCall['POST /payments/simulate'], {
          'X-Order-Access-Token': _accessToken,
        });
        expect(
          client.bodiesByCall['POST /payments/simulate'],
          {'order_id': _orderId, 'simulate_success': true},
        );

        final tickets = await TicketService(
          api: api,
          orderTokens: tokens,
        ).listTickets(query: {'order_id': _orderId});
        expect(client.headersByCall['GET /tickets/my-tickets'], {
          'X-Order-Access-Token': _accessToken,
        });
        expect(tickets.single['order_id'], _orderId);
        expect(TicketModel.fromJson(tickets.single).isValid, isTrue);
      });


      test('provider menyimpan state order, pembayaran, dan tiket', () async {
        final orderProvider = OrderProvider(
          OrderService(api: api, orderTokens: tokens),
        );
        final created = await orderProvider.createOrder(
          eventId: _eventId,
          selectedTicketQuantities: {_ticketTypeId: 1},
          attendees: [
            {
              'ticket_type_id': _ticketTypeId,
              'name': 'Budi Santoso',
              'email': 'budi@example.test',
            },
          ],
          idempotencyKey: 'stage1-idempotency-key-0001',
        );

        expect(created?.id, _orderId);
        expect(orderProvider.selectedOrder?.isPending, isTrue);
        expect(orderProvider.selectedOrder?.grandTotal, 30000);

        final paymentProvider = PaymentProvider(
          PaymentService(api: api, orderTokens: tokens),
        );
        expect(await paymentProvider.loadPayment(_orderId), isTrue);
        expect(paymentProvider.isPending, isTrue);
        expect(
          await paymentProvider.simulatePayment(
            orderId: _orderId,
            virtualAccountNumber: '8800112233445566',
          ),
          isTrue,
        );
        expect(paymentProvider.isPaid, isTrue);

        final ticketProvider = TicketProvider(
          TicketService(api: api, orderTokens: tokens),
        );
        expect(
          await ticketProvider.loadTickets(query: {'order_id': _orderId}),
          isTrue,
        );
        expect(ticketProvider.tickets.single.isValid, isTrue);
        expect(ticketProvider.tickets.single.attendeeName, 'Budi Santoso');
      });

      test('kegagalan API tidak diganti data mock', () async {
        final provider = OrderProvider(
          OrderService(
            api: ApiService(client: _FailingOrderApiClient()),
            orderTokens: tokens,
          ),
        );

        final created = await provider.createOrder(
          eventId: _eventId,
          selectedTicketQuantities: {_ticketTypeId: 1},
        );

        expect(created, isNull);
        expect(provider.error, isNotNull);
        expect(provider.orders, isEmpty);
      });
    },
  );
}

