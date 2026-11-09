/// Organizer packages and subscription management service (PRD section 4.11, FR-76–79).
///
/// Provides plan overview, tier quotas/limits, subscription status tracking,
/// plan upgrade/downgrade simulation, and transaction payment history.
library;

import '../../core/config/app_config.dart';

class OrganizerPlanModel {
  final String id;
  final String name;
  final String badge;
  final double priceMonthly;
  final String priceDescription;
  final List<String> features;
  final int maxActiveEvents;
  final int maxTicketsPerEvent;
  final bool allowExport;
  final bool allowCustomBranding;
  final bool isCurrent;

  const OrganizerPlanModel({
    required this.id,
    required this.name,
    required this.badge,
    required this.priceMonthly,
    required this.priceDescription,
    required this.features,
    required this.maxActiveEvents,
    required this.maxTicketsPerEvent,
    required this.allowExport,
    required this.allowCustomBranding,
    this.isCurrent = false,
  });
}

class OrganizerSubscriptionModel {
  final String id;
  final String organizerId;
  final String planId;
  final String planName;
  final String status; // 'active', 'pending_renewal', 'expired'
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;

  const OrganizerSubscriptionModel({
    required this.id,
    required this.organizerId,
    required this.planId,
    required this.planName,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = true,
  });

  int get remainingDays => endDate.difference(DateTime.now()).inDays;
}

class PlanTransactionModel {
  final String id;
  final String invoiceNumber;
  final String planName;
  final double amount;
  final String paymentMethod;
  final String status; // 'success', 'pending', 'failed'
  final DateTime transactionDate;

  const PlanTransactionModel({
    required this.id,
    required this.invoiceNumber,
    required this.planName,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.transactionDate,
  });
}

class OrganizerPlansService {
  OrganizerPlansService._internal();
  static final OrganizerPlansService instance = OrganizerPlansService._internal();
  factory OrganizerPlansService() => instance;

  static final List<OrganizerPlanModel> _availablePlans = [
    const OrganizerPlanModel(
      id: 'plan-free',
      name: 'Starter (Gratis)',
      badge: 'Dasar',
      priceMonthly: 0,
      priceDescription: 'Gratis untuk komunitas awal',
      features: [
        'Maksimal 2 event aktif sekaligus',
        'Hingga 100 tiket per event',
        'Verifikasi QR scanner online',
        'Dukungan email standar',
      ],
      maxActiveEvents: 2,
      maxTicketsPerEvent: 100,
      allowExport: false,
      allowCustomBranding: false,
    ),
    const OrganizerPlanModel(
      id: 'plan-pro',
      name: 'Professional',
      badge: 'Populer',
      priceMonthly: 299000,
      priceDescription: 'Rp 299.000 / bulan (simulasi demo)',
      features: [
        'Hingga 10 event aktif sekaligus',
        'Hingga 2.000 tiket per event',
        'Verifikasi QR offline & sinkronisasi batch',
        'Ekspor data peserta ke format CSV',
        'Manajemen tim hingga 15 staf panitia',
        'Dukungan prioritas 24 jam',
      ],
      maxActiveEvents: 10,
      maxTicketsPerEvent: 2000,
      allowExport: true,
      allowCustomBranding: true,
      isCurrent: true,
    ),
    const OrganizerPlanModel(
      id: 'plan-enterprise',
      name: 'Enterprise Event',
      badge: 'Skala Besar',
      priceMonthly: 999000,
      priceDescription: 'Rp 999.000 / bulan (simulasi demo)',
      features: [
        'Event aktif tanpa batas',
        'Kuota tiket tanpa batas',
        'Multi-gate scanner & staf unlimited',
        'Ekspor lanjutan & analitik kustom',
        'Manajer akun khusus platform',
      ],
      maxActiveEvents: 999,
      maxTicketsPerEvent: 999999,
      allowExport: true,
      allowCustomBranding: true,
    ),
  ];

  static OrganizerSubscriptionModel _currentSubscription = OrganizerSubscriptionModel(
    id: 'sub-2026-001',
    organizerId: 'org-001',
    planId: 'plan-pro',
    planName: 'Professional',
    status: 'active',
    startDate: DateTime.now().subtract(const Duration(days: 15)),
    endDate: DateTime.now().add(const Duration(days: 45)),
    autoRenew: true,
  );

  static final List<PlanTransactionModel> _mockTransactions = [
    PlanTransactionModel(
      id: 'trx-001',
      invoiceNumber: 'INV-PLAN-2026-001',
      planName: 'Professional Plan (1 Bulan)',
      amount: 299000,
      paymentMethod: 'Virtual Account BCA (Demo)',
      status: 'success',
      transactionDate: DateTime.now().subtract(const Duration(days: 15)),
    ),
    PlanTransactionModel(
      id: 'trx-002',
      invoiceNumber: 'INV-PLAN-2026-002',
      planName: 'Starter Upgrade to Professional',
      amount: 299000,
      paymentMethod: 'QRIS (Demo)',
      status: 'success',
      transactionDate: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  /// Gets list of all available tiers.
  Future<List<OrganizerPlanModel>> getAvailablePlans() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _availablePlans;
    }
    return _availablePlans;
  }

  /// Gets active subscription for current organizer.
  Future<OrganizerSubscriptionModel> getCurrentSubscription() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _currentSubscription;
    }
    return _currentSubscription;
  }

  /// Changes or upgrades the current plan.
  Future<bool> changePlan(String newPlanId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final selected = _availablePlans.firstWhere(
        (p) => p.id == newPlanId,
        orElse: () => _availablePlans[1],
      );

      _currentSubscription = OrganizerSubscriptionModel(
        id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
        organizerId: 'org-001',
        planId: selected.id,
        planName: selected.name,
        status: 'active',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        autoRenew: true,
      );

      _mockTransactions.insert(
        0,
        PlanTransactionModel(
          id: 'trx-${DateTime.now().millisecondsSinceEpoch}',
          invoiceNumber: 'INV-PLAN-${DateTime.now().millisecondsSinceEpoch}',
          planName: '${selected.name} (Simulasi Upgrade)',
          amount: selected.priceMonthly,
          paymentMethod: 'Simulasi Saldo / VA',
          status: 'success',
          transactionDate: DateTime.now(),
        ),
      );

      return true;
    }
    return true;
  }

  /// Gets transaction payment history for subscription packages.
  Future<List<PlanTransactionModel>> getTransactionHistory() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _mockTransactions;
    }
    return _mockTransactions;
  }
}

