/// Organizer Owner Dashboard Screen (PRD section 7.4 A, FR-66).
///
/// Responsive dashboard summarizing owner's own-event statistics (draft, review,
/// published, tickets sold, pending orders, checked-in count, gross sales), recent events,
/// and moderation / revision alerts without displaying platform commission revenue.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_shell/organizer_shell_service.dart';
import '../events/widgets/organizer_feedback_view.dart';
import '../shell/organizer_shell.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key, this.dashboardService});

  final OrganizerShellService? dashboardService;

  @override
  State<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  late final OrganizerShellService _shellService =
      widget.dashboardService ?? OrganizerShellService.instance;
  OrganizerDashboardMetrics? _metrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final m = await _shellService.getDashboardMetrics('org-001');
      if (!mounted) return;
      setState(() => _metrics = m);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent() async {
    final created = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.organizerEventCreate,
    );
    if (created == true && mounted) await _loadMetrics();
  }

  Future<void> _openEvent(String eventId) async {
    await Navigator.pushNamed<void>(
      context,
      AppRoutes.organizerEventDetail.replaceFirst(':id', eventId),
    );
    if (mounted) await _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerDashboard,
      title: 'Dashboard Penyelenggara',
      actions: [
        IconButton(
          tooltip: 'Segarkan',
          icon: const Icon(Icons.refresh),
          onPressed: _loadMetrics,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tambah Event'),
        onPressed: _createEvent,
      ),
      child: _isLoading
          ? const OrganizerLoadingView(message: 'Memuat ringkasan event...')
          : _error != null
          ? OrganizerErrorView(message: _error!, onRetry: _loadMetrics)
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Header
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => Card(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: const Icon(
                                  Icons.business_center,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selamat datang, ${auth.user?.name ?? 'Penyelenggara'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kelola seluruh acara, kuota tiket, dan staf panitia dalam satu tempat.',
                                      style: TextStyle(
                                        fontSize: 13,
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
                    ),

                    const SizedBox(height: 16),

                    // Moderation & Revision Alerts (FR-66)
                    if (_metrics != null &&
                        _metrics!.moderationAlerts.isNotEmpty) ...[
                      ..._metrics!.moderationAlerts.map(
                        (alert) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade900,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alert,
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Metrics KPI Grid 2x2 / 4-card
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              child: _buildMetricCard(
                                context,
                                title: 'Tiket Terjual',
                                value: '${_metrics?.totalTicketsSold ?? 0}',
                                subtitle:
                                    'dari ${_metrics?.totalEvents ?? 0} event',
                                icon: Icons.confirmation_number_outlined,
                                color: Colors.indigo,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildMetricCard(
                                context,
                                title: 'Peserta Check-in',
                                value: '${_metrics?.attendeesCheckedIn ?? 0}',
                                subtitle:
                                    '${((_metrics?.checkInRate ?? 0) * 100).toInt()}% kehadiran',
                                icon: Icons.how_to_reg,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              child: _buildMetricCard(
                                context,
                                title: 'Total Penjualan Kotor',
                                value:
                                    'Rp ${((_metrics?.grossSales ?? 0) / 1000000).toStringAsFixed(1)} Jt',
                                subtitle: 'Penjualan tiket milik Anda',
                                icon: Icons.payments_outlined,
                                color: Colors.green.shade800,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildMetricCard(
                                context,
                                title: 'Pesanan Pending',
                                value: '${_metrics?.pendingOrders ?? 0}',
                                subtitle: 'Menunggu pembayaran',
                                icon: Icons.hourglass_top_outlined,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Lifecycle status counts
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceAround,
                          spacing: 18,
                          runSpacing: 12,
                          children: [
                            _buildMiniStatus(
                              'Tayang',
                              '${_metrics?.publishedEvents ?? 0}',
                              Colors.green,
                            ),
                            _buildMiniStatus(
                              'Review',
                              '${_metrics?.pendingReviewEvents ?? 0}',
                              Colors.orange,
                            ),
                            _buildMiniStatus(
                              'Revisi',
                              '${_metrics?.revisionEvents ?? 0}',
                              Colors.deepOrange,
                            ),
                            _buildMiniStatus(
                              'Draf',
                              '${_metrics?.draftEvents ?? 0}',
                              Colors.grey,
                            ),
                            _buildMiniStatus(
                              'Total',
                              '${_metrics?.totalEvents ?? 0}',
                              Colors.indigo,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions Row
                    Text(
                      'Pintasan Pengelolaan Acara:',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.people_alt_outlined),
                            label: const Text('Tim & Staf'),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.organizerTeam,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.card_membership_outlined),
                            label: const Text('Paket Saya'),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.organizerPlans,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent Events Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Event Milik Saya',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.organizerEvents,
                          ),
                          child: const Text('Lihat Semua'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_metrics?.recentEvents.isEmpty ?? true)
                      const SizedBox(
                        height: 190,
                        child: OrganizerEmptyView(
                          title: 'Belum ada event',
                          description: 'Buat draft event pertama untuk mulai mengelola acara.',
                        ),
                      )
                    else
                      ..._metrics!.recentEvents.map((e) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Text(
                              e['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${e['category']} • ${e['location']}\n'
                              'Tanggal: ${e['start_date']} • '
                              '${e['tickets_sold']} tiket • '
                              '${e['participants']} peserta',
                            ),
                            isThreeLine: true,
                            trailing: _buildEventStatusBadge(
                              e['status'] as String,
                            ),
                            onTap: () => _openEvent(e['id'] as String),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatus(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEventStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'published':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Tayang';
        break;
      case 'pending_review':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Review';
        break;
      case 'draft':
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'Draf';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
