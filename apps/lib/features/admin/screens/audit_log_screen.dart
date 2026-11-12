/// Administrative audit log viewer screen (PRD Section 6.11, FR-104, FR-105, FR-106).
library;

import 'package:flutter/material.dart';

import '../../../models/admin/admin_audit_log_model.dart';
import '../../../services/admin/admin_audit_log_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AdminAuditLogService _auditService = AdminAuditLogService.instance;
  List<AdminAuditLogEntry> _logs = [];
  bool _isLoading = true;
  String _entityFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final list = await _auditService.getAuditLogs(
        entityFilter: _entityFilter == 'ALL' ? null : _entityFilter,
        searchQuery: _searchCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _logs = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Tindakan Admin'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari tindakan, aktor, ID entitas, alasan...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadLogs();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadLogs(),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Semua Entitas', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Event', 'EVENT'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Akun User', 'USER'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Paket', 'PACKAGE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Langganan', 'SUBSCRIPTION'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pengaturan', 'SETTINGS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada catatan audit log yang cocok.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildActionIcon(log.action),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _buildActionBadge(log.action),
                                                const SizedBox(width: 8),
                                                Text(
                                                  log.entityType,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log.details ?? log.action,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatDate(log.timestamp),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (log.reason != null && log.reason!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Alasan: ${log.reason}',
                                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Aktor: ${log.actorName} (${log.actorRole})',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                      ),
                                      Text(
                                        'ID: ${log.entityId}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                        ),
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

  Widget _buildFilterChip(String label, String value) {
    final selected = _entityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _entityFilter = value);
          _loadLogs();
        }
      },
    );
  }

  Widget _buildActionIcon(String action) {
    IconData icon = Icons.check_circle_outline;
    Color color = Colors.green;

    if (action.contains('SUSPEND') || action.contains('DEACTIVATE') || action.contains('REJECT')) {
      icon = Icons.cancel_outlined;
      color = Colors.red;
    } else if (action.contains('FEE') || action.contains('SETTINGS')) {
      icon = Icons.settings_outlined;
      color = Colors.orange;
    } else if (action.contains('PACKAGE')) {
      icon = Icons.inventory_2_outlined;
      color = Colors.blue;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg = Colors.green.shade50;
    Color fg = Colors.green.shade800;

    if (action.contains('SUSPEND') || action.contains('REJECT')) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else if (action.contains('SETTINGS') || action.contains('FEE')) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else if (action.contains('PACKAGE')) {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        action,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

