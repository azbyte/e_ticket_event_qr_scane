import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/event/event_model.dart';
import '../../../providers/event_provider.dart';
import '../../../services/organizer_events/organizer_event_contract.dart';
import '../../../services/organizer_events/organizer_event_fixtures.dart';
import '../../../services/organizer_events/organizer_event_repository.dart';
import '../../../services/organizer_events/mock_organizer_event_repository.dart';
import '../../organizer/events/screens/organizer_event_detail_screen.dart';
import '../../organizer/events/screens/organizer_event_preview_screen.dart';
import '../../organizer/events/widgets/organizer_event_card.dart';
import '../../organizer/events/widgets/organizer_feedback_view.dart';
import 'event_form_screen.dart';

/// Halaman "Event Saya" milik Owner (PRD 5.3).
///
/// Daftar ini hanya memuat event milik Owner aktif dari fixture lokal; tidak ada
/// request jaringan. Aksi yang tidak diizinkan oleh status event disembunyikan.
class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({
    super.key,
    this.ownerId,
    this.repository,
  });

  /// Owner aktif; default memakai fixture Owner demo.
  final String? ownerId;

  /// Repository kustom (dipakai test untuk fixture tertentu).
  final OrganizerEventRepository? repository;

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late final EventProvider _provider;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = EventProvider(
      repository: widget.repository ?? MockOrganizerEventRepository.shared(),
      ownerId: widget.ownerId ?? OrganizerEventFixtures.demoOwnerId,
    );
    _provider.loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EventFormScreen(repository: _provider.repository),
      ),
    );
    if (created == true && mounted) {
      await _provider.loadEvents();
    }
  }

  Future<void> _openDetail(EventModel event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OrganizerEventDetailScreen(
          eventId: event.id,
          provider: _provider,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _provider.loadEvents();
    }
  }

  Future<void> _editEvent(EventModel event) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EventFormScreen(
          eventId: event.id,
          repository: _provider.repository,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _provider.loadEvents();
    }
  }

  Future<void> _copyLink(EventModel event) async {
    await Clipboard.setData(ClipboardData(text: event.registrationUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          event.registrationUrlIsDemo
              ? 'Tautan demo disalin. Event belum dipublikasikan ke server.'
              : 'Tautan publik disalin.',
        ),
      ),
    );
  }

  Future<void> _previewEvent(EventModel event) async {
    final types = await _provider.repository.listTicketTypes(
      ownerId: _provider.ownerId,
      eventId: event.id,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganizerEventPreviewScreen(
          event: event,
          ticketTypes: types,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _provider,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Event Saya'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: () => _provider.loadEvents(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('event-create-fab'),
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: const Text('Buat event'),
          ),
          body: _buildBody(),
        ),
      );

  Widget _buildBody() {
    if (_provider.hasAccessDenied) {
      return const OrganizerAccessDeniedView(
        message: 'Daftar event tidak dapat dimuat untuk akun ini.',
      );
    }
    if (_provider.hasError) {
      return OrganizerErrorView(
        message: _provider.loadError ?? 'Terjadi kesalahan saat memuat event.',
        onRetry: () => _provider.loadEvents(),
      );
    }
    if (_provider.isLoading && _provider.events.isEmpty) {
      return const OrganizerLoadingView();
    }
    if (_provider.isEmpty) {
      return OrganizerEmptyView(
        title: 'Belum ada event',
        description: 'Buat draft event pertama, lalu ajukan moderasi setelah '
            'informasi dan kategori tiket lengkap.',
        primaryLabel: 'Buat event',
        onPrimary: _createEvent,
      );
    }
    return Column(
      children: <Widget>[
        _buildSearchField(),
        _buildFilterChips(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          key: const Key('event-search-field'),
          controller: _searchController,
          onChanged: _provider.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Cari nama event, lokasi, atau kategori',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _provider.searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Bersihkan pencarian',
                    onPressed: () {
                      _searchController.clear();
                      _provider.setSearchQuery('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
      );

  Widget _buildFilterChips() => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: OrganizerEventFilter.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = OrganizerEventFilter.values[index];
            return ChoiceChip(
              label: Text(filter.label),
              selected: _provider.filter == filter,
              onSelected: (_) => _provider.setFilter(filter),
            );
          },
        ),
      );

  Widget _buildList() {
    if (_provider.hasNoMatch) {
      return OrganizerEmptyView(
        icon: Icons.search_off,
        title: 'Tidak ada event yang cocok',
        description: 'Ubah kata kunci pencarian atau pilih filter status lain.',
        secondaryLabel: 'Reset pencarian',
        onSecondary: () {
          _searchController.clear();
          _provider.setSearchQuery('');
          _provider.setFilter(OrganizerEventFilter.all);
        },
      );
    }

    final events = _provider.visibleEvents;
    return RefreshIndicator(
      onRefresh: _provider.loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final summary = _provider.summaryFor(event.id);
          return OrganizerEventCard(
            key: ValueKey<String>(event.id),
            event: event,
            ticketsSold: summary?.ticketsSold,
            participants: summary?.participants,
            onOpen: () => _openDetail(event),
            onEdit: () => _editEvent(event),
            onSubmitForReview: () => _submitForReview(event),
            onPreview: () => _previewEvent(event),
            onCopyLink: () => _copyLink(event),
            onDelete: () => _deleteEvent(event),
          );
        },
      ),
    );
  }

  Future<void> _submitForReview(EventModel event) async {
    final resubmit = event.canResubmit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(resubmit ? 'Ajukan ulang moderasi?' : 'Ajukan moderasi?'),
        content: Text(
          resubmit
              ? 'Event akan dikirim ulang ke moderator beserta perbaikan Anda.'
              : 'Event akan dikirim ke moderator dan status berubah menjadi '
                  '"Menunggu moderasi" (simulasi).',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated =
        await _provider.submitForReview(event.id, resubmit: resubmit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated == null
              ? (_provider.actionError ?? 'Pengajuan gagal.')
              : 'Status event: ${updated.statusLabel} (simulasi).',
        ),
      ),
    );
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus draft event?'),
        content: Text(
          '"${event.title}" beserta kategori tiketnya akan dihapus dari '
          'fixture lokal dan tidak dapat dikembalikan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await _provider.deleteEvent(event.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Draft "${event.title}" dihapus.'
              : (_provider.actionError ?? 'Gagal menghapus draft.'),
        ),
      ),
    );
  }
}