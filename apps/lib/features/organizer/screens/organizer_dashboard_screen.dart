/// Dashboard Organizer Owner (PRD section 7.4 A, FR-66).
///
/// Halaman utama Organizer: sapaan singkat, peringatan moderasi/revisi, dan
/// daftar event milik Organizer beserta aksinya. Data dimuat dari repository
/// backend yang sama dengan halaman "Event Saya" (bukan data contoh).
///
/// Kartu statistik dan pintasan ganda sengaja tidak ditampilkan: fokus halaman
/// ada pada pengelolaan event. Tim & Staf, Paket, serta Bantuan dibuka dari
/// halaman yang paling relevan (detail event dan Profil).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as core;
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_events/organizer_event_contract.dart';
import '../../../services/organizer_events/organizer_event_fixtures.dart';
import '../../../services/organizer_shell/organizer_shell_service.dart';
import '../events/widgets/organizer_event_status_chip.dart';
import '../events/widgets/organizer_feedback_view.dart';
import '../shell/organizer_content_frame.dart';
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

  List<Map<String, dynamic>> get _events =>
      _metrics?.recentEvents ?? const <Map<String, dynamic>>[];

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
      final auth = context.read<AuthProvider>();
      final userId = AppConfig.mockMode
          ? OrganizerEventFixtures.demoOwnerId
          : (auth.user?.id ?? '');
      final metrics = await _shellService.getDashboardMetrics(userId);
      if (!mounted) return;
      setState(() => _metrics = metrics);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _openEventList() async {
    await Navigator.pushNamed<void>(context, AppRoutes.organizerEvents);
    if (mounted) await _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerDashboard,
      title: 'Dashboard',
      actions: <Widget>[
        IconButton(
          tooltip: 'Segarkan',
          icon: const Icon(Icons.refresh, color: Color(0xFF181818)),
          onPressed: _loadMetrics,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dashboard-create-event-fab'),
        onPressed: _createEvent,
        backgroundColor: const Color(0xFFC94426),
        foregroundColor: const Color(0xFFFFFFFF),
        splashColor: const Color(0xFFA8351C),
        icon: const Icon(Icons.add, color: Color(0xFFFFFFFF)),
        label: const Text(
          'Tambah Event',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const OrganizerLoadingView(message: 'Memuat event Anda...');
    }
    if (_error != null) {
      return OrganizerErrorView(message: _error!, onRetry: _loadMetrics);
    }
    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: OrganizerContentFrame(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            _buildGreeting(),
            if (_metrics != null && _metrics!.moderationAlerts.isNotEmpty) ...[
              const SizedBox(height: 20),
              ..._metrics!.moderationAlerts.map(_buildModerationAlert),
            ],
            const SizedBox(height: 24),
            _buildEventSectionHeader(),
            const SizedBox(height: 12),
            if (_events.isEmpty)
              _buildEmptyEvents()
            else
              ..._events.map(_buildEventTile),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final name = auth.user?.name.trim() ?? '';
        final displayName = name.isEmpty ? 'Penyelenggara' : name;
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Halo, $displayName',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF181818),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kelola event, tiket, dan check-in dari satu tempat.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7A7A7A),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModerationAlert(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSectionHeader() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Event Milik Saya',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF181818),
            ),
          ),
        ),
        TextButton(
          key: const Key('dashboard-open-event-list'),
          onPressed: _openEventList,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFC94426),
          ),
          child: const Text('Lihat semua'),
        ),
      ],
    );
  }

  Widget _buildEmptyEvents() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const Key('dashboard-events-empty'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada event',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buat event pertama Anda, lengkapi kategori tiket, lalu ajukan '
            'moderasi untuk mulai menjual tiket.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _createEvent,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat event pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final eventId = event['id'] as String? ?? '';
    final title = (event['title'] as String?)?.trim() ?? '';
    final location = (event['location'] as String?)?.trim() ?? '';
    final date = core.DateUtils.formatDate(
      DateTime.tryParse(event['start_date'] as String? ?? ''),
    );
    final ticketsSold = event['tickets_sold'] as int? ?? 0;
    final participants = event['participants'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E2E2), width: 1),
      ),
      child: InkWell(
        key: Key('dashboard-event-$eventId'),
        onTap: () => _openEvent(eventId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Tanpa judul' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF181818),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrganizerEventStatusChip(
                    status:
                        event['status'] as String? ??
                        OrganizerEventStatus.draft,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMetaRow(
                icon: Icons.event_outlined,
                primary: date,
                secondary: location,
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 14,
                    color: Color(0xFF7A7A7A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$ticketsSold tiket',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.people_outline,
                    size: 14,
                    color: Color(0xFF7A7A7A),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$participants peserta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF7A7A7A),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String primary,
    String? secondary,
  }) {
    const style = TextStyle(fontSize: 12, color: Color(0xFF7A7A7A));
    final hasSecondary = secondary != null && secondary.isNotEmpty;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: const Color(0xFF7A7A7A)),
        const SizedBox(width: 4),
        Text(primary, style: style),
        if (hasSecondary) ...<Widget>[
          const Text(
            ' • ',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
          ),
          Expanded(
            child: Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}
