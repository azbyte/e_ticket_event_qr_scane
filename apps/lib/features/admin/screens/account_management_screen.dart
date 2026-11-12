/// Account management screen (admin) — PRD sections 6.4, 7.6, FR-87, FR-88.
///
/// Management of Platform Users (Organizers & Participants), status suspension
/// with mandatory reason recording, and simulated audit logging.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';

/// Model internal akun platform untuk prototipe UI Admin.
class PlatformAccountItem {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' | 'organizer' | 'participant'
  final String? organizationName;
  final String? activePlan;
  final int eventCount;
  final int orderCount;
  final DateTime joinedAt;
  final bool isDisabled;
  final String? suspensionReason;

  const PlatformAccountItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.organizationName,
    this.activePlan,
    this.eventCount = 0,
    this.orderCount = 0,
    required this.joinedAt,
    this.isDisabled = false,
    this.suspensionReason,
  });

  PlatformAccountItem copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? organizationName,
    String? activePlan,
    int? eventCount,
    int? orderCount,
    DateTime? joinedAt,
    bool? isDisabled,
    String? suspensionReason,
    bool clearSuspensionReason = false,
  }) {
    return PlatformAccountItem(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationName: organizationName ?? this.organizationName,
      activePlan: activePlan ?? this.activePlan,
      eventCount: eventCount ?? this.eventCount,
      orderCount: orderCount ?? this.orderCount,
      joinedAt: joinedAt ?? this.joinedAt,
      isDisabled: isDisabled ?? this.isDisabled,
      suspensionReason: clearSuspensionReason ? null : (suspensionReason ?? this.suspensionReason),
    );
  }
}

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all'; // all, active, disabled

  // In-memory mock database of accounts
  static final List<PlatformAccountItem> _mockAccounts = [
    PlatformAccountItem(
      id: 'usr-admin',
      name: 'Super Administrator',
      email: 'admin@event.com',
      role: 'admin',
      joinedAt: DateTime(2025, 1, 1),
      isDisabled: false,
    ),
    PlatformAccountItem(
      id: 'usr-org-001',
      name: 'Organizer Event Nusantara',
      email: 'organizer@event.com',
      role: 'organizer',
      organizationName: 'PT Event Kreasi Nusantara',
      activePlan: 'Pro',
      eventCount: 4,
      joinedAt: DateTime(2025, 2, 10),
      isDisabled: false,
    ),
    PlatformAccountItem(
      id: 'usr-org-002',
      name: 'Komunitas Flutter Indonesia',
      email: 'flutter@community.id',
      role: 'organizer',
      organizationName: 'Flutter Developer Community',
      activePlan: 'Basic',
      eventCount: 2,
      joinedAt: DateTime(2025, 5, 18),
      isDisabled: false,
    ),
    PlatformAccountItem(
      id: 'usr-org-003',
      name: 'Event Organizer Nakal',
      email: 'nakal@event.id',
      role: 'organizer',
      organizationName: 'CV Tiket Gelap Fiktif',
      activePlan: 'Basic',
      eventCount: 1,
      joinedAt: DateTime(2025, 6, 1),
      isDisabled: true,
      suspensionReason: 'Terindikasi pelanggaran: duplikasi penjualan tiket fiktif.',
    ),
    PlatformAccountItem(
      id: 'usr-part-001',
      name: 'Budi Santoso',
      email: 'budi@example.com',
      role: 'participant',
      orderCount: 3,
      joinedAt: DateTime(2025, 4, 15),
      isDisabled: false,
    ),
    PlatformAccountItem(
      id: 'usr-part-002',
      name: 'Dewi Lestari',
      email: 'dewi.lestari@example.com',
      role: 'participant',
      orderCount: 1,
      joinedAt: DateTime(2025, 6, 20),
      isDisabled: false,
    ),
    PlatformAccountItem(
      id: 'usr-part-003',
      name: 'Siti Nurhaliza',
      email: 'siti.nur@example.com',
      role: 'participant',
      orderCount: 2,
      joinedAt: DateTime(2025, 7, 5),
      isDisabled: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<PlatformAccountItem> _getFilteredAccounts(String? targetRole) {
    var list = List<PlatformAccountItem>.from(_mockAccounts);

    if (targetRole != null) {
      list = list.where((a) => a.role == targetRole).toList();
    }

    if (_statusFilter == 'active') {
      list = list.where((a) => !a.isDisabled).toList();
    } else if (_statusFilter == 'disabled') {
      list = list.where((a) => a.isDisabled).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((a) {
        return a.name.toLowerCase().contains(query) ||
            a.email.toLowerCase().contains(query) ||
            (a.organizationName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return list;
  }

  void _showSuspendDialog(PlatformAccountItem account) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Tangguhkan ${account.name}')),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akun ${account.email} (${account.role.toUpperCase()}) akan dinonaktifkan dari sistem platform.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sesuai ketentuan PRD FR-88, penangguhan akun WAJIB mencatat alasan pada AuditLog:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Penangguhan Akun *',
                    hintText: 'Cth: Terbukti melanggar syarat & ketentuan pembayaran tiket...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Alasan penangguhan wajib diisi.';
                    }
                    if (val.trim().length < 5) {
                      return 'Alasan terlalu pendek (min 5 karakter).';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              _performSuspend(account, reasonController.text.trim());
            },
            child: const Text('Tangguhkan Akun'),
          ),
        ],
      ),
    );
  }

  void _performSuspend(PlatformAccountItem account, String reason) {
    final idx = _mockAccounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) {
      setState(() {
        _mockAccounts[idx] = _mockAccounts[idx].copyWith(
          isDisabled: true,
          suspensionReason: reason,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun "${account.name}" berhasil ditangguhkan. Alasan dicatat ke AuditLog.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _showReactivateDialog(PlatformAccountItem account) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('Aktifkan ${account.name}?')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin memulihkan akses untuk ${account.email}?'),
              if (account.suspensionReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Alasan penangguhan sebelumnya: "${account.suspensionReason}"',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              final idx = _mockAccounts.indexWhere((a) => a.id == account.id);
              if (idx != -1) {
                setState(() {
                  _mockAccounts[idx] = _mockAccounts[idx].copyWith(
                    isDisabled: false,
                    clearSuspensionReason: true,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Akun "${account.name}" telah diaktifkan kembali.'),
                    backgroundColor: Colors.green.shade800,
                  ),
                );
              }
            },
            child: const Text('Aktifkan Kembali'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengelolaan Akun Platform'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua Akun'),
            Tab(text: 'Organizer'),
            Tab(text: 'Participant'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, email, organisasi...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Status: Semua')),
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(value: 'disabled', child: Text('Ditangguhkan')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _statusFilter = val);
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Semua Akun
                _buildAccountsList(null, currentUserId),

                // Tab 2: Organizer
                _buildAccountsList('organizer', currentUserId),

                // Tab 3: Participant
                _buildAccountsList('participant', currentUserId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(String? targetRole, String? currentUserId) {
    final accounts = _getFilteredAccounts(targetRole);

    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('Tidak ada akun yang sesuai kriteria.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = accounts[index];
        final isSelf = item.id == currentUserId || item.email == 'admin@event.com';

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: item.isDisabled
                ? BorderSide(color: Colors.red.shade300)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: item.isDisabled
                          ? Colors.red.shade100
                          : item.role == 'admin'
                              ? Colors.indigo.shade100
                              : item.role == 'organizer'
                                  ? Colors.teal.shade100
                                  : Colors.blue.shade100,
                      child: Icon(
                        item.role == 'admin'
                            ? Icons.admin_panel_settings
                            : item.role == 'organizer'
                                ? Icons.business
                                : Icons.person,
                        color: item.isDisabled ? Colors.red : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              _buildRoleBadge(item.role),
                            ],
                          ),
                          Text(
                            item.email,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(item.isDisabled),
                  ],
                ),

                const SizedBox(height: 8),

                // Specific Info per Role (PRD 6.4)
                if (item.role == 'organizer') ...[
                  Row(
                    children: [
                      Icon(Icons.domain, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Org: ${item.organizationName ?? "-"} • Paket: ${item.activePlan ?? "Free"} • Event: ${item.eventCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ] else if (item.role == 'participant') ...[
                  Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Total Pemesanan Tiket: ${item.orderCount} order',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ],

                // Suspension Reason Banner
                if (item.isDisabled && item.suspensionReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Alasan Penangguhan: ${item.suspensionReason}',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                    ),
                  ),
                ],

                const Divider(height: 16),

                // Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bergabung: ${item.joinedAt.day}/${item.joinedAt.month}/${item.joinedAt.year}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (isSelf)
                      const Text(
                        'Akun Anda Saat Ini',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                      )
                    else if (item.isDisabled)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          backgroundColor: Colors.green.shade50,
                        ),
                        onPressed: () => _showReactivateDialog(item),
                        child: const Text('Aktifkan Kembali'),
                      )
                    else
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _showSuspendDialog(item),
                        child: const Text('Tangguhkan'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;
    switch (role) {
      case 'admin':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade900;
        break;
      case 'organizer':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade900;
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(bool isDisabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isDisabled ? 'Ditangguhkan' : 'Aktif',
        style: TextStyle(
          color: isDisabled ? Colors.red.shade800 : Colors.green.shade800,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
