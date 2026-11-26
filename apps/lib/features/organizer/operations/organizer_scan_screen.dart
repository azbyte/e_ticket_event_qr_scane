/// Halaman tab "Scan QR" untuk Organizer.
///
/// Validasi tiket dilakukan backend per event (`POST /api/tickets/validate` dan
/// `POST /api/check-ins`), sehingga pemindaian harus terikat pada satu event.
/// Tab ini menampilkan daftar event milik Organizer dari repository backend
/// sebagai titik masuk kamera pemindai — tanpa data contoh.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/date_utils.dart' as core;
import '../../../models/event/event_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_events/organizer_event_contract.dart';
import '../../../services/organizer_events/organizer_event_fixtures.dart';
import '../../../services/organizer_events/organizer_event_repository.dart';
import '../../../services/organizer_events/organizer_event_repository_factory.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../events/widgets/organizer_event_status_chip.dart';
import '../events/widgets/organizer_feedback_view.dart';
import '../screens/event_form_screen.dart';
import '../shell/organizer_content_frame.dart';
import '../shell/organizer_shell.dart';
import 'organizer_scanner_screen.dart';

class OrganizerScanScreen extends StatefulWidget {
  const OrganizerScanScreen({super.key, this.repository});

  /// Repository kustom (dipakai test); default mengikuti mode aplikasi.
  final OrganizerEventRepository? repository;

  @override
  State<OrganizerScanScreen> createState() => _OrganizerScanScreenState();
}

class _OrganizerScanScreenState extends State<OrganizerScanScreen> {
  late final OrganizerEventRepository _repository =
      widget.repository ?? createOrganizerEventRepository();

  List<EventModel> _events = const <EventModel>[];
  bool _isLoading = true;
  String? _error;

  String get _ownerId => AppConfig.mockMode
      ? OrganizerEventFixtures.demoOwnerId
      : (context.read<AuthProvider>().user?.id ?? '');

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final ownerId = _ownerId;
    if (ownerId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Sesi Organizer tidak ditemukan. Silakan masuk kembali.';
      });
      return;
    }
    try {
      final events = await _repository.listEvents(ownerId: ownerId);
      if (!mounted) return;
      setState(() => _events = events);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EventFormScreen(repository: _repository, ownerId: _ownerId),
      ),
    );
    if (created == true && mounted) await _loadEvents();
  }

  Future<void> _openScanner(EventModel event) async {
    final auth = context.read<AuthProvider>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganizerScannerScreen(
          eventId: event.id,
          eventName: event.title,
          contextScope: OrganizerMembershipContext.owner(
            eventId: event.id,
            userId: auth.user?.id ?? '',
            userName: auth.user?.name ?? 'Penyelenggara',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerScan,
      title: 'Pindai Tiket',
      actions: <Widget>[
        IconButton(
          tooltip: 'Segarkan',
          icon: const Icon(Icons.refresh),
          onPressed: _loadEvents,
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const OrganizerLoadingView(message: 'Memuat event Anda...');
    }
    if (_error != null) {
      return OrganizerErrorView(message: _error!, onRetry: _loadEvents);
    }
    if (_events.isEmpty) {
      return OrganizerEmptyView(
        icon: Icons.qr_code_scanner,
        title: 'Belum ada event untuk dipindai',
        description:
            'Pemindaian tiket terikat pada satu event. Buat event terlebih '
            'dahulu, lalu kembali ke tab ini untuk mulai memindai.',
        primaryLabel: 'Buat event',
        onPrimary: _createEvent,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: OrganizerContentFrame(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            const OrganizerInfoBanner(
              message:
                  'Pilih event yang sedang berlangsung. Validasi tiket dilakukan '
                  'per event agar check-in tercatat pada acara yang tepat.',
            ),
            const SizedBox(height: 20),
            Text(
              'Pilih event',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Ketuk event untuk membuka kamera pemindai QR tiket.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ..._events.map(_buildEventTile),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(EventModel event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final location = event.needsPhysicalLocation
        ? (event.location ?? 'Lokasi belum diisi')
        : (event.onlineUrl ?? 'Acara online');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('scan-event-${event.id}'),
        onTap: () => _openScanner(event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.7,
                ),
                child: Icon(Icons.qr_code_scanner, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${core.DateUtils.formatDateTime(event.startDateTime)}'
                      ' • $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OrganizerEventStatusChip(status: event.status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
