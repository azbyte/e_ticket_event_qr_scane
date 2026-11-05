/// Organizer event activity log screen (PRD sections 13.3 & PEMBAGIAN_TUGAS_2).
///
/// Timeline of operational event actions (creation, revisions, invitations,
/// assisted registrations, check-ins, and exports).
library;

import 'package:flutter/material.dart';

import '../../../services/organizer_operations/event_activity_service.dart';

class OrganizerActivityLogScreen extends StatefulWidget {
  const OrganizerActivityLogScreen({
    super.key,
    required this.eventId,
    this.eventTitle = 'Tech Innovation Summit 2026',
  });

  final String eventId;
  final String eventTitle;

  @override
  State<OrganizerActivityLogScreen> createState() =>
      _OrganizerActivityLogScreenState();
}

class _OrganizerActivityLogScreenState
    extends State<OrganizerActivityLogScreen> {
  final EventActivityLogger _logger = EventActivityLogger.instance;
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'CHECK_IN',
    'REGISTRATION',
    'EVENT',
    'STAFF',
    'EXPORT',
  ];

  String _formatCategoryLabel(String cat) {
    switch (cat) {
      case 'CHECK_IN':
        return 'Check-In';
      case 'REGISTRATION':
        return 'Registrasi';
      case 'EVENT':
        return 'Event & Tiket';
      case 'STAFF':
        return 'Tim & Staf';
      case 'EXPORT':
        return 'Ekspor';
      default:
        return 'Semua';
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('SUCCESS') || action.contains('CHECK_IN_SUCCESS')) {
      return Colors.green;
    }
    if (action.contains('FAILED') || action.contains('DENIED')) {
      return Colors.red;
    }
    if (action.contains('OFFLINE')) {
      return Colors.orange;
    }
    if (action.contains('REGISTRATION')) {
      return Colors.indigo;
    }
    if (action.contains('STAFF')) {
      return Colors.purple;
    }
    if (action.contains('EXPORT')) {
      return Colors.teal;
    }
    return Colors.blueGrey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('CHECK_IN')) {
      return Icons.qr_code_scanner;
    }
    if (action.contains('REGISTRATION')) {
      return Icons.app_registration;
    }
    if (action.contains('STAFF')) {
      return Icons.group;
    }
    if (action.contains('EXPORT')) {
      return Icons.file_download;
    }
    if (action.contains('EVENT') || action.contains('TICKET')) {
      return Icons.event;
    }
    return Icons.history;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Aktivitas Acara'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _logger,
        builder: (context, _) {
          final entries = _logger.getActivitiesForEvent(
            widget.eventId,
            actionCategory: _selectedCategory,
          );

          return Column(
            children: [
              // Event title header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(Icons.event_note, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.eventTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entries.length} Catatan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_formatCategoryLabel(cat)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(height: 1),

              // Timeline List
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada log aktivitas untuk kategori "${_formatCategoryLabel(_selectedCategory)}".',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = entries[index];
                          final actionColor = _getActionColor(item.action);

                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: actionColor.withValues(alpha: 0.12),
                                    foregroundColor: actionColor,
                                    radius: 20,
                                    child: Icon(_getActionIcon(item.action), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.actorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(item.timestamp),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.summary,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: actionColor.withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.action,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: actionColor,
                                                ),
                                              ),
                                            ),
                                            if (item.metadata != null &&
                                                item.metadata!['order_id'] != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                'Order: ${item.metadata!['order_id']}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
