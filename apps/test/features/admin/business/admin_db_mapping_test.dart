import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_settings_service.dart';

/// Regresi: konsol Admin harus membaca bentuk respons database yang sebenarnya.
///
/// Sebelum perbaikan, dashboard membaca `data['orders']`, `data['tickets']`,
/// `data['gross_sales']`, dan `data['platform_commission']` yang TIDAK pernah
/// dikirim backend. Akibatnya seluruh metrik jatuh ke angka contoh dan aplikasi
/// terlihat tidak memakai database. `GET /api/admin/settings` juga dibaca dari
/// `response['data']` padahal backend mengirim `settings`/`history`.
void main() {
  group('PlatformRevenueSummary.fromOverview — kontrak /api/admin/overview', () {
    test('memetakan field database ke metrik dashboard', () {
      final summary = PlatformRevenueSummary.fromOverview({
        'events': {
          'total': 7,
          'published': 3,
          'pending_review': 2,
          'revision_requested': 1,
          'rejected': 1,
          'suspended': 0,
          'draft': 1,
        },
        'active_organizers': 4,
        'total_orders': 12,
        'tickets_sold': 30,
        'total_participants': 28,
        'total_check_ins': 9,
        'financials': {
          'gross_amount': 1500000,
          'commission_amount': 75000,
          'service_fee': 10000,
          'platform_revenue': 85000,
          'organizer_net_amount': 1415000,
        },
        'trends': [
          {
            'week': '2026-11-16T00:00:00.000Z',
            'gross': 500000,
            'revenue': 25000,
            'transactions': 3,
          },
        ],
      });

      expect(summary.eventsTotal, 7);
      expect(summary.eventsPublished, 3);
      expect(summary.eventsPendingReview, 2);
      expect(summary.eventsRejected, 1);
      expect(summary.totalOrganizers, 4);
      expect(summary.totalOrders, 12);
      expect(summary.totalTicketsIssued, 30);
      expect(summary.totalParticipants, 28);
      expect(summary.totalCheckIns, 9);
      expect(summary.revenue.grossTicketSales, 1500000);
      expect(summary.revenue.ticketCommissionRevenue, 75000);
      expect(summary.revenue.totalPlatformRevenue, 85000);
      expect(summary.trends.single.gross, 500000);
      expect(summary.trends.single.transactions, 3);
    });

    test('nilai string numeric dari pg tetap terbaca', () {
      final summary = PlatformRevenueSummary.fromOverview({
        'events': {'total': '2'},
        'total_orders': '5',
        'financials': {'gross_amount': '100000', 'platform_revenue': '5000'},
      });

      expect(summary.eventsTotal, 2);
      expect(summary.totalOrders, 5);
      expect(summary.revenue.grossTicketSales, 100000);
      expect(summary.revenue.totalPlatformRevenue, 5000);
    });

    test('database kosong menghasilkan nol, bukan angka contoh', () {
      final summary = PlatformRevenueSummary.fromOverview({
        'events': {
          'total': 0,
          'published': 0,
          'pending_review': 0,
          'rejected': 0,
          'suspended': 0,
          'draft': 0,
        },
        'active_organizers': 0,
        'total_orders': 0,
        'tickets_sold': 0,
        'total_participants': 0,
        'total_check_ins': 0,
        'financials': {
          'gross_amount': 0,
          'commission_amount': 0,
          'platform_revenue': 0,
        },
        'trends': const [],
      });

      expect(summary.eventsTotal, 0);
      expect(summary.totalTicketsIssued, 0);
      expect(summary.totalOrganizers, 0);
      expect(summary.revenue.totalPlatformRevenue, 0);
      expect(summary.trends, isEmpty);
    });

    test('ringkasan kosong awal tidak memuat angka contoh', () {
      final empty = PlatformRevenueSummary.empty();
      expect(empty.eventsTotal, 0);
      expect(empty.totalParticipants, 0);
      expect(empty.revenue.grossTicketSales, 0);
    });
  });

  group('parsePlatformSettings — kontrak /api/admin/settings', () {
    test('membaca key flat dari tabel platform_settings', () {
      final settings = parsePlatformSettings({
        'platform_name': 'E-Ticket Kampus',
        'support_email': 'support@kampus.test',
        'contact_phone': '+62 812 0000 1111',
        'ticket_commission_rate': 5,
        'fixed_service_fee': 5000,
        'order_payment_timeout_minutes': 90,
        'refund_policy_summary': 'Refund H-3.',
        'updated_at': '2026-11-26T06:59:58.346Z',
        'updated_by': 'Administrator Platform',
      });

      expect(settings.platformName, 'E-Ticket Kampus');
      expect(settings.contactEmail, 'support@kampus.test');
      expect(settings.contactPhone, '+62 812 0000 1111');
      expect(settings.ticketCommissionRate, 5);
      expect(settings.fixedServiceFee, 5000);
      expect(settings.orderPaymentTimeoutMinutes, 90);
      expect(settings.refundPolicySummary, 'Refund H-3.');
      expect(settings.lastUpdatedBy, 'Administrator Platform');
    });

    test('membuka nilai JSONB berbentuk { value: ... }', () {
      final settings = parsePlatformSettings({
        'ticket_commission_rate': {'value': 7},
        'fixed_service_fee': {'value': 2500},
      });

      expect(settings.ticketCommissionRate, 7);
      expect(settings.fixedServiceFee, 2500);
    });

    test('key yang belum ada memakai default keputusan produk C-01', () {
      final settings = parsePlatformSettings(const {});

      expect(settings.ticketCommissionRate, kDefaultTicketCommissionRate);
      expect(settings.fixedServiceFee, kDefaultFixedServiceFee);
      expect(
        settings.orderPaymentTimeoutMinutes,
        kDefaultOrderPaymentTimeoutMinutes,
      );
    });
  });

  group('parsePlatformFeeHistory — tabel platform_setting_history', () {
    test('hanya menampilkan baris perubahan tarif komisi', () {
      final entries = parsePlatformFeeHistory([
        {
          'id': 'h-2',
          'setting_key': 'ticket_commission_rate',
          'old_value': 7,
          'new_value': 5,
          'changed_at': '2026-11-20T10:00:00.000Z',
          'changed_by_id': 'user-1',
          'changed_by_name': 'Administrator Platform',
          'reason': 'Promosi kuartal',
        },
        {
          'id': 'h-1',
          'setting_key': 'platform_name',
          'old_value': 'Lama',
          'new_value': 'Baru',
          'changed_at': '2026-11-21T10:00:00.000Z',
        },
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.oldCommissionRate, 7);
      expect(entries.single.newCommissionRate, 5);
      expect(entries.single.actorName, 'Administrator Platform');
      expect(entries.single.reason, 'Promosi kuartal');
    });

    test('daftar kosong tidak menghasilkan entri palsu', () {
      expect(parsePlatformFeeHistory(const []), isEmpty);
    });
  });

  group('AppConfig.healthUrl', () {
    test('menurunkan URL /health dari base API (tanpa segmen /api)', () {
      // Di test VM `defaultTargetPlatform` = Android, sehingga base API default
      // 10.0.2.2:5000/api. Yang diuji adalah transformasinya, bukan host.
      expect(AppConfig.healthUrl, endsWith('/health'));
      expect(AppConfig.healthUrl, isNot(contains('/api/health')));
      expect(AppConfig.healthUrl, startsWith('http'));
      expect(AppConfig.healthUrl, AppConfig.apiBaseUrl.replaceAll('/api', '/health'));
    });
  });
}
