/// Organizer subscription management screen for Platform Admin (PRD Section 6.6, FR-79).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin/admin_subscription_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin/admin_subscription_service.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final AdminSubscriptionService _service = AdminSubscriptionService.instance;
  List<AdminSubscriptionModel> _subscriptions = [];
  bool _isLoading = true;
  String _statusFilter = 'ALL';
  String _planFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getSubscriptions(
        statusFilter: _statusFilter == 'ALL' ? null : _statusFilter,
        planFilter: _planFilter == 'ALL' ? null : _planFilter,
        searchQuery: _searchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _subscriptions = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuspendDialog(AdminSubscriptionModel sub) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tangguhkan Langganan Organizer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tangguhkan akses langganan paket "${sub.planName}" milik "${sub.organizerName}"?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan Penangguhan *',
                hintText: 'Misal: Menunggu konfirmasi pembayaran rekening',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final auth = context.read<AuthProvider>();
              Navigator.pop(ctx);

              await _service.suspendSubscription(
                sub.id,
                reason: reason,
                actorId: auth.user?.id ?? 'usr-admin-01',
                actorName: auth.user?.name ?? 'Super Admin',
              );
              messenger.showSnackBar(
                SnackBar(content: Text('Langganan ${sub.organizerName} ditangguhkan.')),
              );
              _loadSubscriptions();
            },
            child: const Text('Tangguhkan'),
          ),
        ],
      ),
    );
  }

  void _showExtendDialog(AdminSubscriptionModel sub) {
    final daysCtrl = TextEditingController(text: '7');
    final reasonCtrl = TextEditingController(text: 'Kompensasi administratif');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perpanjang Masa Aktif Langganan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah masa aktif untuk "${sub.organizerName}" (${sub.planName}).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Hari Tambahan *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan Penambahan *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
              final reason = reasonCtrl.text.trim();
              if (days <= 0 || reason.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              final auth = context.read<AuthProvider>();
              Navigator.pop(ctx);

              await _service.extendSubscription(
                sub.id,
                days,
                reason: reason,
                actorId: auth.user?.id ?? 'usr-admin-01',
                actorName: auth.user?.name ?? 'Super Admin',
              );
              messenger.showSnackBar(
                SnackBar(content: Text('Masa aktif berhasil diperpanjang $days hari.')),
              );
              _loadSubscriptions();
            },
            child: const Text('Perpanjang'),
          ),
        ],
      ),
    );
  }

  void _showDetailHistoryModal(AdminSubscriptionModel sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detail Langganan & Riwayat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${sub.organizerName} (${sub.organizerEmail})',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const Divider(height: 24),
              // Plan info
              _buildInfoRow('Paket Layanan', sub.planName),
              _buildInfoRow('Status Langganan', sub.status),
              _buildInfoRow('Periode Aktif', '${_formatDate(sub.startDate)} s/d ${_formatDate(sub.endDate)}'),
              _buildInfoRow('Sisa Waktu', '${sub.remainingDays} hari'),
              _buildInfoRow('Perpanjangan Otomatis', sub.autoRenew ? 'Aktif' : 'Tidak Aktif'),
              const SizedBox(height: 20),
              // Plan Change History (FR-79)
              const Text(
                'Riwayat Perubahan Paket:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (sub.changeHistory.isEmpty)
                Text('Belum ada catatan riwayat perubahan paket.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              else
                ...sub.changeHistory.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.change_circle_outlined, color: Colors.indigo),
                    title: Text('${c.fromPlan} → ${c.toPlan}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${c.reason}\n${_formatDate(c.changedAt)}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              const SizedBox(height: 16),
              // Payment History (FR-79)
              const Text(
                'Riwayat Pembayaran Paket:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (sub.paymentHistory.isEmpty)
                Text('Belum ada riwayat pembayaran faktur.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
              else
                ...sub.paymentHistory.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.green),
                      title: Text(p.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${p.paymentMethod} • ${_formatDate(p.paidAt)}', style: const TextStyle(fontSize: 11)),
                      trailing: Text('Rp ${p.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Langganan Organizer'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubscriptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari organizer, email, atau paket...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadSubscriptions();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadSubscriptions(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Semua Status')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                          DropdownMenuItem(value: 'PENDING_PAYMENT', child: Text('PENDING PAYMENT')),
                          DropdownMenuItem(value: 'EXPIRED', child: Text('EXPIRED')),
                          DropdownMenuItem(value: 'SUSPENDED', child: Text('SUSPENDED')),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
                            _loadSubscriptions();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _planFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter Paket',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Semua Paket')),
                          DropdownMenuItem(value: 'pkg-starter', child: Text('Starter')),
                          DropdownMenuItem(value: 'pkg-pro', child: Text('Professional')),
                          DropdownMenuItem(value: 'pkg-enterprise', child: Text('Enterprise')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _planFilter = val);
                            _loadSubscriptions();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.card_membership_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data langganan organizer.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _subscriptions.length,
                        itemBuilder: (context, index) {
                          final sub = _subscriptions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: const Icon(Icons.business, color: Colors.indigo),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sub.organizerName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              sub.organizerEmail,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusBadge(sub.status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sub.planName,
                                          style: TextStyle(
                                            color: Colors.indigo.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Berakhir: ${_formatDate(sub.endDate)} (${sub.remainingDays} hari lagi)',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.history, size: 16),
                                        label: const Text('Detail & Riwayat'),
                                        onPressed: () => _showDetailHistoryModal(sub),
                                      ),
                                      const SizedBox(width: 8),
                                      if (sub.isActive)
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                          onPressed: () => _showSuspendDialog(sub),
                                          child: const Text('Tangguhkan'),
                                        )
                                      else if (sub.isSuspended)
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);
                                            final auth = context.read<AuthProvider>();
                                            await _service.activateSubscription(
                                              sub.id,
                                              actorId: auth.user?.id ?? 'usr-admin-01',
                                              actorName: auth.user?.name ?? 'Super Admin',
                                            );
                                            messenger.showSnackBar(
                                              SnackBar(content: Text('Langganan ${sub.organizerName} telah diaktifkan kembali.')),
                                            );
                                            _loadSubscriptions();
                                          },
                                          child: const Text('Aktifkan'),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Perpanjang Masa Aktif',
                                        icon: const Icon(Icons.more_time),
                                        onPressed: () => _showExtendDialog(sub),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.green.shade50;
    Color fg = Colors.green.shade800;

    if (status == 'SUSPENDED') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else if (status == 'EXPIRED') {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
    } else if (status == 'PENDING_PAYMENT') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

