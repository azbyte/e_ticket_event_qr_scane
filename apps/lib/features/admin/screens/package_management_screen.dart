/// Package management screen for Platform Admin (PRD Section 6.5, FR-74, FR-75, FR-76).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin/admin_package_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin/admin_package_service.dart';

class PackageManagementScreen extends StatefulWidget {
  const PackageManagementScreen({super.key});

  @override
  State<PackageManagementScreen> createState() => _PackageManagementScreenState();
}

class _PackageManagementScreenState extends State<PackageManagementScreen> {
  final AdminPackageService _packageService = AdminPackageService.instance;
  List<AdminPackageModel> _packages = [];
  bool _isLoading = true;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    try {
      final list = await _packageService.getPackages(
        statusFilter: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      if (mounted) {
        setState(() {
          _packages = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPackageFormDialog([AdminPackageModel? existing]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceMonthCtrl = TextEditingController(
      text: existing != null ? existing.priceMonthly.toInt().toString() : '0',
    );
    final priceYearCtrl = TextEditingController(
      text: existing != null ? existing.priceYearly.toInt().toString() : '0',
    );
    final maxEventsCtrl = TextEditingController(
      text: existing != null ? existing.maxActiveEvents.toString() : '5',
    );
    final maxTicketsCtrl = TextEditingController(
      text: existing != null ? existing.maxTicketsPerEvent.toString() : '500',
    );
    final maxStaffCtrl = TextEditingController(
      text: existing != null ? existing.maxStaffPerEvent.toString() : '5',
    );

    bool isFree = existing?.isFree ?? false;
    bool hasReports = existing?.hasAdvancedReports ?? false;
    bool hasExport = existing?.hasExportAttendees ?? false;
    bool hasBranding = existing?.hasCustomBranding ?? false;
    bool hasAnalytics = existing?.hasAnalytics ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Buat Paket Layanan Baru' : 'Edit Paket Layanan'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Paket *',
                      hintText: 'Contoh: Professional Plus',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Paket *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Deskripsi wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Paket Gratis (Free)'),
                    subtitle: const Text('Centang jika paket tidak berbayar.'),
                    value: isFree,
                    onChanged: (val) {
                      setDialogState(() {
                        isFree = val;
                        if (isFree) {
                          priceMonthCtrl.text = '0';
                          priceYearCtrl.text = '0';
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!isFree) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceMonthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga / Bulan (Rp) *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: priceYearCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga / Tahun (Rp) *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Batasan Penggunaan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxEventsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks Event Aktif',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: maxTicketsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks Tiket/Event',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: maxStaffCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks Staf',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Fitur Tambahan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  CheckboxListTile(
                    title: const Text('Laporan Penjualan Lanjutan'),
                    value: hasReports,
                    onChanged: (v) => setDialogState(() => hasReports = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Ekspor Data Peserta (CSV/Excel)'),
                    value: hasExport,
                    onChanged: (v) => setDialogState(() => hasExport = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Kustomisasi Branding & Sertifikat'),
                    value: hasBranding,
                    onChanged: (v) => setDialogState(() => hasBranding = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Analitik & Grafik Komprehensif'),
                    value: hasAnalytics,
                    onChanged: (v) => setDialogState(() => hasAnalytics = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final auth = context.read<AuthProvider>();
                  final actorId = auth.user?.id ?? 'usr-admin-01';
                  final actorName = auth.user?.name ?? 'Super Admin';

                  final pkg = AdminPackageModel(
                    id: existing?.id ?? 'pkg-${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    priceMonthly: double.tryParse(priceMonthCtrl.text.trim()) ?? 0,
                    priceYearly: double.tryParse(priceYearCtrl.text.trim()) ?? 0,
                    status: existing?.status ?? 'active',
                    isFree: isFree,
                    maxActiveEvents: int.tryParse(maxEventsCtrl.text.trim()) ?? 2,
                    maxTicketsPerEvent: int.tryParse(maxTicketsCtrl.text.trim()) ?? 100,
                    maxStaffPerEvent: int.tryParse(maxStaffCtrl.text.trim()) ?? 2,
                    hasAdvancedReports: hasReports,
                    hasExportAttendees: hasExport,
                    hasCustomBranding: hasBranding,
                    hasAnalytics: hasAnalytics,
                    activeSubscribersCount: existing?.activeSubscribersCount ?? 0,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );

                  Navigator.pop(ctx);
                  if (existing == null) {
                    await _packageService.createPackage(
                      pkg,
                      actorId: actorId,
                      actorName: actorName,
                    );
                    messenger.showSnackBar(
                      SnackBar(content: Text('Paket "${pkg.name}" berhasil dibuat.')),
                    );
                  } else {
                    await _packageService.updatePackage(
                      pkg,
                      actorId: actorId,
                      actorName: actorName,
                      reason: 'Pembaruan data paket oleh admin.',
                    );
                    messenger.showSnackBar(
                      SnackBar(content: Text('Paket "${pkg.name}" berhasil diperbarui.')),
                    );
                  }
                  _loadPackages();
                }
              },
              child: Text(existing == null ? 'Simpan Paket' : 'Perbarui'),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveConfirmDialog(AdminPackageModel pkg) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan Paket Layanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin mengarsipkan paket "${pkg.name}"? Paket yang diarsipkan tidak akan tampil bagi pendaftar baru tetapi data historis tetap aman.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan Pengarsipan *',
                hintText: 'Misal: Penyesuaian skema harga baru',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.brown),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final auth = context.read<AuthProvider>();
              Navigator.pop(ctx);

              await _packageService.archivePackage(
                pkg.id,
                actorId: auth.user?.id ?? 'usr-admin-01',
                actorName: auth.user?.name ?? 'Super Admin',
                reason: reason,
              );
              messenger.showSnackBar(
                SnackBar(content: Text('Paket "${pkg.name}" telah diarsipkan.')),
              );
              _loadPackages();
            },
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Paket Layanan'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadPackages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Buat Paket Baru'),
        onPressed: () => _showPackageFormDialog(),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('Semua Paket', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Aktif', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Nonaktif', 'inactive'),
                const SizedBox(width: 8),
                _buildFilterChip('Diarsipkan', 'archived'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _packages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada paket layanan ditemukan.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _packages.length,
                        itemBuilder: (context, index) {
                          final pkg = _packages[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  pkg.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildStatusBadge(pkg.status),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pkg.description,
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (val) async {
                                          if (val == 'edit') {
                                            _showPackageFormDialog(pkg);
                                          } else if (val == 'toggle') {
                                            final messenger = ScaffoldMessenger.of(context);
                                            final auth = context.read<AuthProvider>();
                                            await _packageService.togglePackageStatus(
                                              pkg.id,
                                              actorId: auth.user?.id ?? 'usr-admin-01',
                                              actorName: auth.user?.name ?? 'Super Admin',
                                            );
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Status paket "${pkg.name}" berhasil diubah.',
                                                ),
                                              ),
                                            );
                                            _loadPackages();
                                          } else if (val == 'archive') {
                                            _showArchiveConfirmDialog(pkg);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit Paket'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  pkg.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(pkg.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                                              ],
                                            ),
                                          ),
                                          if (!pkg.isArchived)
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.archive_outlined, size: 18, color: Colors.brown),
                                                  SizedBox(width: 8),
                                                  Text('Arsipkan', style: TextStyle(color: Colors.brown)),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Price
                                  Row(
                                    children: [
                                      Text(
                                        pkg.isFree ? 'Gratis' : 'Rp ${pkg.priceMonthly.toInt()} / bulan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      if (!pkg.isFree) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '(Rp ${pkg.priceYearly.toInt()} / thn)',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${pkg.activeSubscribersCount} Organizer Aktif',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  // Limits & Features
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      _buildFeatureChip(Icons.event, 'Maks ${pkg.maxActiveEvents} Event'),
                                      _buildFeatureChip(Icons.confirmation_number, 'Maks ${pkg.maxTicketsPerEvent} Tiket/Event'),
                                      _buildFeatureChip(Icons.badge, 'Maks ${pkg.maxStaffPerEvent} Staf'),
                                      if (pkg.hasAdvancedReports)
                                        _buildFeatureChip(Icons.analytics, 'Laporan Lanjutan'),
                                      if (pkg.hasExportAttendees)
                                        _buildFeatureChip(Icons.file_download, 'Ekspor Peserta'),
                                      if (pkg.hasCustomBranding)
                                        _buildFeatureChip(Icons.brush, 'Branding'),
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

  Widget _buildFilterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _statusFilter = value);
          _loadPackages();
        }
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.green.shade50;
    Color fg = Colors.green.shade800;
    String label = 'AKTIF';

    if (status == 'inactive') {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
      label = 'NONAKTIF';
    } else if (status == 'archived') {
      bg = Colors.brown.shade50;
      fg = Colors.brown.shade800;
      label = 'DIARSIPKAN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.indigo.shade700),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

