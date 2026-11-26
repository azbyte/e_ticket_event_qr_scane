/// Ticket service (PRD sections 4.6, 6.3).
library;

import '../../core/config/app_config.dart';
import '../../core/services/order_access_token_store.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class TicketService {
  TicketService({ApiService? api, OrderAccessTokenStore? orderTokens})
    : _api = api ?? ApiService(),
      _orderTokens = orderTokens ?? const SecureOrderAccessTokenStore();

  final ApiService _api;
  final OrderAccessTokenStore _orderTokens;
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<List<Map<String, dynamic>>> listTickets({
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = query?['q'] as String?;
      final tickets = _mockRepo.getTickets(query: q);
      return tickets.map((t) => t.toJson()).toList();
    }

    final params = <String, dynamic>{...?query};
    final orderId = params['order_id'] as String?;
    String? accessToken;
    if (orderId != null) {
      accessToken = await _orderTokens.read(orderId);
    }
    final result = await _api.get(
      '/tickets/my-tickets',
      query: params.isEmpty ? null : params,
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
    final data = result['tickets'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTicket(
    String ticketId, {
    String? orderId,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getTicketById(ticketId).toJson();
    }

    final accessToken = orderId == null
        ? null
        : await _orderTokens.read(orderId);
    final result = await _api.get(
      '/tickets/$ticketId',
      query: orderId == null ? null : {'order_id': orderId},
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
    final ticket = Map<String, dynamic>.from(result['ticket'] as Map);
    // Sertakan status email bila backend mengirimkannya (pemilik/admin).
    if (result['email_delivery'] != null) {
      ticket['email_delivery'] = result['email_delivery'];
    }
    return ticket;
  }

  /// Kirim ulang e-ticket ke email peserta.
  ///
  /// Backend tidak mengirim ganda: bila tiket sudah `SENT`, hasilnya
  /// `SKIPPED/already_sent` dan tidak ada email baru.
  Future<Map<String, dynamic>> resendTicketEmail(
    String ticketId, {
    String? orderId,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return <String, dynamic>{
        'delivered': false,
        'delivery_status': 'NOT_CONFIGURED',
        'reason': 'Mode demo tidak mengirim email sungguhan.',
      };
    }

    final accessToken = orderId == null
        ? null
        : await _orderTokens.read(orderId);
    return _api.post(
      '/tickets/$ticketId/email',
      body: orderId == null ? null : {'order_id': orderId},
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
  }
}
