/// Organizer subscription packages and transaction history screen (FR-76–79).
///
/// Overview of active plan, features, event and ticket limits, upgrade simulation,
/// and transaction invoice history without processing real monetary payments.
library;

import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../services/organizer_plans/organizer_plans_service.dart';
import '../events/widgets/organizer_feedback_view.dart';
import '../shell/organizer_shell.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final OrganizerPlansService _service = OrganizerPlansService.instance;

  OrganizerSubscriptionModel? _subscription;
  List<OrganizerPlanModel> _plans = [];
  List<PlanTransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isChangingPlan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final sub = await _service.getCurrentSubscription();
      final plans = await _service.getAvailablePlans();
      final trxs = await _service.getTransactionHistory();
      if (!mounted) return;
      setState(() {
        _subscription = sub;
        _plans = plans;
        _transactions = trxs;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUpgradeDialog(OrganizerPlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upgrade, color: Colors.indigo),
            const SizedBox(width: 8),
            Text('Pilih Paket ${plan.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biaya: ${plan.priceDescription}'),
            const SizedBox(height: 12),
            const Text(
              'Catatan: Ini adalah alur simulasi UI prototype (Tahap 0). Tidak ada penagihan uang nyata.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text('Keuntungan paket:'),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _isChangingPlan
                ? null
                : () async {
                    setState(() => _isChangingPlan = true);
                    Navigator.pop(ctx);
                    try {
                      final changed = await _service.changePlan(plan.id);
                      if (!mounted) return;
                      if (!changed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Paket demo tidak ditemukan.'),
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Paket demo dialihkan ke ${plan.name}. Tidak ada penagihan.',
                          ),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                      await _loadData();
                    } on Exception catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Paket gagal diubah: $error')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isChangingPlan = false);
                    }
                  },
            child: const Text('Konfirmasi Pilihan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerPlans,
      title: 'Paket & Langganan',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? OrganizerErrorView(message: _loadError!, onRetry: _loadData)
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.stars), text: 'Paket & Fitur'),
                    Tab(
                      icon: Icon(Icons.receipt_long),
                      text: 'Riwayat Transaksi',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildPlansTab(), _buildTransactionsTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlansTab() {
    if (_plans.isEmpty) {
      return const OrganizerEmptyView(
        title: 'Paket belum tersedia',
        description: 'Belum ada paket demo yang dapat ditampilkan.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current Subscription Banner
          if (_subscription != null)
            Card(
              color: Colors.indigo.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.indigo,
                      child: const Icon(Icons.verified, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Paket Aktif: ${_subscription!.planName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AKTIF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sisa masa aktif: ${_subscription!.remainingDays} hari (hingga ${_subscription!.endDate.day}/${_subscription!.endDate.month}/${_subscription!.endDate.year})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          Text(
            'Pilihan Paket Penyelenggara Acara:',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Plan comparison cards
          ..._plans.map((p) {
            final isCurrent = _subscription?.planId == p.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: isCurrent ? 3 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isCurrent ? Colors.indigo : Colors.grey.shade300,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.indigo.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCurrent ? 'PAKET ANDA' : p.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.indigo
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.priceDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Divider(height: 20),
                    ...p.features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: isCurrent ? null : () => _showUpgradeDialog(p),
                      child: Text(
                        isCurrent ? 'Sedang Digunakan' : 'Pilih Paket Ini',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text('Belum ada riwayat transaksi paket.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final trx = _transactions[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.receipt, color: Colors.white),
            ),
            title: Text(
              trx.planName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${trx.invoiceNumber}\n${trx.paymentMethod} • ${trx.transactionDate.day}/${trx.transactionDate.month}/${trx.transactionDate.year}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${trx.amount.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trx.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
