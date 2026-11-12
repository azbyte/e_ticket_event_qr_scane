/// Admin subscription management service (PRD Section 6.6, FR-79).
library;

import '../../models/admin/admin_subscription_model.dart';
import 'admin_audit_log_service.dart';

class AdminSubscriptionService {
  AdminSubscriptionService._internal();
  static final AdminSubscriptionService instance =
      AdminSubscriptionService._internal();
  factory AdminSubscriptionService() => instance;

  final AdminAuditLogService _auditLogService = AdminAuditLogService.instance;

  final List<AdminSubscriptionModel> _subscriptions = [
    AdminSubscriptionModel(
      id: 'sub-001',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      organizerEmail: 'organizer@event.com',
      planId: 'pkg-pro',
      planName: 'Professional',
      status: 'ACTIVE',
      startDate: DateTime.now().subtract(const Duration(days: 15)),
      endDate: DateTime.now().add(const Duration(days: 45)),
      autoRenew: true,
      lastPaymentAmount: 299000,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 15)),
      changeHistory: [
        SubscriptionChangeEvent(
          fromPlan: 'Starter (Gratis)',
          toPlan: 'Professional',
          changedAt: DateTime.now().subtract(const Duration(days: 45)),
          reason: 'Upgrade mandiri oleh organizer.',
        ),
      ],
      paymentHistory: [
        SubscriptionPaymentRecord(
          invoiceNumber: 'INV-PLAN-2026-001',
          amount: 299000,
          paymentMethod: 'BCA Virtual Account (Demo)',
          status: 'PAID',
          paidAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
        SubscriptionPaymentRecord(
          invoiceNumber: 'INV-PLAN-2025-012',
          amount: 299000,
          paymentMethod: 'QRIS (Demo)',
          status: 'PAID',
          paidAt: DateTime.now().subtract(const Duration(days: 45)),
        ),
      ],
    ),
    AdminSubscriptionModel(
      id: 'sub-002',
      organizerId: 'org-002',
      organizerName: 'Komunitas Flutter ID',
      organizerEmail: 'flutter.id@komunitas.org',
      planId: 'pkg-starter',
      planName: 'Starter (Gratis)',
      status: 'ACTIVE',
      startDate: DateTime.now().subtract(const Duration(days: 60)),
      endDate: DateTime.now().add(const Duration(days: 300)),
      autoRenew: true,
      lastPaymentAmount: 0,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 60)),
      changeHistory: [],
      paymentHistory: [],
    ),
    AdminSubscriptionModel(
      id: 'sub-003',
      organizerId: 'org-003',
      organizerName: 'Festival Musik Kreatif',
      organizerEmail: 'panitia@festivalkreatif.id',
      planId: 'pkg-enterprise',
      planName: 'Enterprise Event',
      status: 'ACTIVE',
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 80)),
      autoRenew: false,
      lastPaymentAmount: 999000,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 10)),
      changeHistory: [],
      paymentHistory: [
        SubscriptionPaymentRecord(
          invoiceNumber: 'INV-PLAN-2026-002',
          amount: 999000,
          paymentMethod: 'Mandiri Bill Payment (Demo)',
          status: 'PAID',
          paidAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ],
    ),
    AdminSubscriptionModel(
      id: 'sub-004',
      organizerId: 'org-004',
      organizerName: 'EO Cahaya Mandiri',
      organizerEmail: 'admin@cahayamandiri.co.id',
      planId: 'pkg-pro',
      planName: 'Professional',
      status: 'SUSPENDED',
      startDate: DateTime.now().subtract(const Duration(days: 40)),
      endDate: DateTime.now().add(const Duration(days: 20)),
      autoRenew: false,
      lastPaymentAmount: 299000,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 40)),
      changeHistory: [],
      paymentHistory: [
        SubscriptionPaymentRecord(
          invoiceNumber: 'INV-PLAN-2026-003',
          amount: 299000,
          paymentMethod: 'BNI Virtual Account (Demo)',
          status: 'PAID',
          paidAt: DateTime.now().subtract(const Duration(days: 40)),
        ),
      ],
    ),
    AdminSubscriptionModel(
      id: 'sub-005',
      organizerId: 'org-005',
      organizerName: 'Universitas Karya Bangsa',
      organizerEmail: 'seminar@karyabangsa.ac.id',
      planId: 'pkg-pro',
      planName: 'Professional',
      status: 'EXPIRED',
      startDate: DateTime.now().subtract(const Duration(days: 65)),
      endDate: DateTime.now().subtract(const Duration(days: 5)),
      autoRenew: false,
      lastPaymentAmount: 299000,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 65)),
      changeHistory: [],
      paymentHistory: [
        SubscriptionPaymentRecord(
          invoiceNumber: 'INV-PLAN-2025-010',
          amount: 299000,
          paymentMethod: 'BCA Virtual Account (Demo)',
          status: 'PAID',
          paidAt: DateTime.now().subtract(const Duration(days: 65)),
        ),
      ],
    ),
  ];

  /// Lists organizer subscriptions with optional filters.
  Future<List<AdminSubscriptionModel>> getSubscriptions({
    String? planFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminSubscriptionModel> result = List.from(_subscriptions);

    if (planFilter != null && planFilter.isNotEmpty && planFilter != 'ALL') {
      result = result.where((s) => s.planId == planFilter).toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      result = result.where((s) => s.status == statusFilter).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((s) {
        return s.organizerName.toLowerCase().contains(q) ||
            s.organizerEmail.toLowerCase().contains(q) ||
            s.planName.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  /// Suspends an organizer subscription administratively (FR-79, FR-104).
  Future<bool> suspendSubscription(
    String subscriptionId, {
    required String reason,
    required String actorId,
    required String actorName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (index != -1) {
      final current = _subscriptions[index];
      _subscriptions[index] = current.copyWith(status: 'SUSPENDED');

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'SUBSCRIPTION_SUSPENDED',
        entityType: 'SUBSCRIPTION',
        entityId: subscriptionId,
        reason: reason,
        details: 'Menangguhkan langganan organizer ${current.organizerName}.',
      );

      return true;
    }
    return false;
  }

  /// Reactivates an organizer subscription (FR-79).
  Future<bool> activateSubscription(
    String subscriptionId, {
    required String actorId,
    required String actorName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (index != -1) {
      final current = _subscriptions[index];
      _subscriptions[index] = current.copyWith(status: 'ACTIVE');

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'SUBSCRIPTION_ACTIVATED',
        entityType: 'SUBSCRIPTION',
        entityId: subscriptionId,
        details: 'Mengaktifkan kembali langganan ${current.organizerName}.',
      );

      return true;
    }
    return false;
  }

  /// Extends active days administratively (FR-79).
  Future<bool> extendSubscription(
    String subscriptionId,
    int additionalDays, {
    required String reason,
    required String actorId,
    required String actorName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (index != -1) {
      final current = _subscriptions[index];
      final newEnd = current.endDate.add(Duration(days: additionalDays));
      _subscriptions[index] = current.copyWith(
        status: 'ACTIVE',
        endDate: newEnd,
      );

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'SUBSCRIPTION_EXTENDED',
        entityType: 'SUBSCRIPTION',
        entityId: subscriptionId,
        reason: reason,
        details: 'Menambah masa aktif $additionalDays hari untuk ${current.organizerName}.',
      );

      return true;
    }
    return false;
  }
}

