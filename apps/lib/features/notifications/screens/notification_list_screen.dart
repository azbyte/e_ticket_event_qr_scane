/// Notification list screen (PRD section: Notifications).
///
/// System announcements, event moderation alerts, trouble ticket updates,
/// and check-in synchronization logs.
library;

import 'package:flutter/material.dart';

import '../../../providers/notification_provider.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({
    super.key,
    this.notificationProvider,
  });

  final NotificationProvider? notificationProvider;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.notificationProvider ?? NotificationProvider();
    _provider.loadNotifications();
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'event_approved':
        return Icons.event_available;
      case 'report_update':
        return Icons.support_agent;
      case 'check_in_sync':
        return Icons.sync;
      case 'staff_invite':
        return Icons.badge;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'event_approved':
        return Colors.green;
      case 'report_update':
        return Colors.indigo;
      case 'check_in_sync':
        return Colors.teal;
      case 'staff_invite':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final notifications = _provider.notifications;
        final unreadCount = _provider.unreadCount;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              unreadCount > 0 ? 'Notifikasi ($unreadCount)' : 'Notifikasi',
            ),
            actions: [
              if (unreadCount > 0)
                TextButton(
                  onPressed: () async {
                    await _provider.markAllAsRead();
                  },
                  child: const Text('Tandai Semua Dibaca'),
                ),
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadNotifications(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _provider.loadNotifications(),
            child: _provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Belum ada pemberitahuan baru.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          final id = item['id'] as String;
                          final title = item['title'] as String? ?? 'Pemberitahuan';
                          final message = item['message'] as String? ?? '';
                          final type = item['type'] as String?;
                          final isRead = item['is_read'] == true;

                          return Card(
                            elevation: isRead ? 0 : 2,
                            color: isRead ? Colors.grey.shade50 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (!isRead) {
                                  _provider.markAsRead(id);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getColorForType(type).withOpacity(0.12),
                                      child: Icon(
                                        _getIconForType(type),
                                        color: _getColorForType(type),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.blue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isRead ? Colors.grey.shade700 : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
