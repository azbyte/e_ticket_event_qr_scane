/// Detail event Organizer dengan subnavigasi Ringkasan, Informasi, dan Tiket.
///
/// Tab Peserta/Tim/Scanner/Laporan/Aktivitas dimiliki Developer 2/3 dan dapat
/// disisipkan lewat [extraTabs] tanpa mengubah file ini.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as core;
import '../../../../models/event/event_model.dart';
import '../../../../models/event/ticket_type_model.dart';
import '../../../../providers/event_provider.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';
import '../../../../services/organizer_events/organizer_event_fixtures.dart';
import '../../../../services/organizer_events/organizer_event_repository.dart';
import '../../../organizer/screens/event_form_screen.dart';
import '../widgets/organizer_event_status_chip.dart';
import '../widgets/organizer_feedback_view.dart';
import '../widgets/organizer_summary_widgets.dart';
import 'organizer_event_preview_screen.dart';
import 'organizer_ticket_type_form_screen.dart';

/// Tab tambahan yang disediakan domain lain (mis. Peserta, Tim, Scanner).
class OrganizerEventExtraTab {
  const OrganizerEventExtraTab({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

class OrganizerEventDetailScreen extends StatefulWidget {
  const OrganizerEventDetailScreen({
    super.key,
    required this.eventId,
    this.extraTabs = const <OrganizerEventExtraTab>[],
    this.provider,
    this.repository,
    this.ownerId,
    this.onRequestReports,
  });

  final String eventId;
  final List<OrganizerEventExtraTab> extraTabs;

  /// Provider yang sudah dimuat; bila null layar memuat sendiri dari repository.
  final EventProvider? provider;

  /// Repository kustom (dipakai test).
  final OrganizerEventRepository? repository;

  /// Owner aktif; default memakai fixture Owner demo.
  final String? ownerId;

  /// Callback opsional menuju tab Laporan milik Developer 2.
  final VoidCallback? onRequestReports;

  @override
  State<OrganizerEventDetailScreen> createState() =>
      _OrganizerEventDetailScreenState();
}

class _OrganizerEventDetailScreenState
    extends State<OrganizerEventDetailScreen> {
  late final EventProvider _provider;
  late final bool _ownsProvider;

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.provider == null;
    _provider =
        widget.provider ??
        EventProvider(
          repository: widget.repository,
          ownerId: widget.ownerId ?? OrganizerEventFixtures.demoOwnerId,
        );
    // Selalu muat detail agar layar dapat dibuka langsung tanpa data awal.
    _provider.loadEvent(widget.eventId);
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
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

  Future<void> _openPreview(EventModel event) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrganizerEventPreviewScreen(event: event),
      ),
    );
  }

  Future<void> _openForm(EventModel event) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EventFormScreen(
          eventId: event.id,
          repository: _provider.repository,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _provider.loadEvent(widget.eventId);
    }
  }

  Future<void> _submitForReview(
    EventModel event, {
    required bool resubmit,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(resubmit ? 'Ajukan ulang moderasi?' : 'Ajukan moderasi?'),
        content: Text(
          resubmit
              ? 'Event akan dikirim ulang ke moderator beserta perbaikan Anda.'
              : 'Event akan dikirim ke moderator. Status berubah menjadi '
                    '"Menunggu moderasi" dan tidak dapat diubah sampai ada '
                    'keputusan (simulasi).',
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

    final updated = await _provider.submitForReview(
      event.id,
      resubmit: resubmit,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated == null
              ? (_provider.actionError ?? 'Pengajuan gagal.')
              : 'Event diajukan. Status: ${updated.statusLabel} (simulasi).',
        ),
      ),
    );
    if (updated != null) await _provider.loadEvent(widget.eventId);
  }

  Future<void> _simulateModeration(EventModel event) async {
    final decision = await showDialog<OrganizerModerationDecision>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Simulasi keputusan moderator'),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Panel ini hanya untuk memperagakan alur moderasi pada prototipe. '
              'Bukan aksi Owner dan tidak mewakili Admin sungguhan.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          for (final option in OrganizerModerationDecision.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option),
              child: Text(option.label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    if (decision == null) return;

    final updated = await _provider.simulateModeration(event.id, decision);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated == null
              ? (_provider.actionError ?? 'Simulasi gagal.')
              : 'Simulasi moderator: ${updated.statusLabel}.',
        ),
      ),
    );
    if (updated != null) await _provider.loadEvent(widget.eventId);
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus draft event?'),
        content: Text(
          '"${event.title}" beserta kategori tiketnya akan dihapus dari '
          'fixture lokal. Tindakan ini tidak dapat dibatalkan.',
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
    if (deleted) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_provider.actionError ?? 'Gagal menghapus draft.'),
      ),
    );
  }

  Future<void> _openTicketForm(
    EventModel event, {
    TicketTypeModel? existing,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OrganizerTicketTypeFormScreen(
          provider: _provider,
          eventId: event.id,
          initial: existing,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _provider.loadEvent(event.id);
    }
  }

  Future<void> _toggleTicketType(EventModel event, TicketTypeModel type) async {
    final ok = await _provider.setTicketTypeActive(
      eventId: event.id,
      ticketTypeId: type.id,
      isActive: !type.isActive,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kategori "${type.name}" '
                    '${type.isActive ? 'dinonaktifkan' : 'diaktifkan'}.'
              : (_provider.actionError ?? 'Gagal mengubah status kategori.'),
        ),
      ),
    );
  }

  Future<void> _deleteTicketType(EventModel event, TicketTypeModel type) async {
    if (type.hasTransactions) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kategori tidak dapat dihapus'),
          content: Text(
            'Kategori "${type.name}" sudah memiliki ${type.sold} tiket terjual '
            'dan ${type.held} kuota tertahan. Riwayat transaksi harus '
            'dipertahankan, jadi kategori hanya dapat dinonaktifkan.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus kategori tiket?'),
        content: Text('"${type.name}" akan dihapus dari event ini.'),
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

    final ok = await _provider.deleteTicketType(
      eventId: event.id,
      ticketTypeId: type.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Kategori "${type.name}" dihapus.'
              : (_provider.actionError ?? 'Gagal menghapus kategori.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _provider,
    builder: (context, _) {
      final event = _provider.selectedEvent;
      final extraTabs = widget.extraTabs;
      final tabs = <OrganizerEventExtraTab>[
        OrganizerEventExtraTab(
          label: 'Ringkasan',
          builder: (_) => _buildRingkasan(event!),
        ),
        OrganizerEventExtraTab(
          label: 'Informasi',
          builder: (_) => _buildInformasi(event!),
        ),
        OrganizerEventExtraTab(
          label: 'Tiket',
          builder: (_) => _buildTiket(event!),
        ),
        ...extraTabs,
      ];

      return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              event?.title ?? 'Detail Event',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              if (event != null) ...<Widget>[
                IconButton(
                  tooltip: 'Pratinjau publik',
                  onPressed: () => _openPreview(event),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                IconButton(
                  tooltip: 'Salin tautan registrasi',
                  onPressed: () => _copyLink(event),
                  icon: const Icon(Icons.link),
                ),
                if (event.canBeEdited)
                  IconButton(
                    tooltip: 'Edit event',
                    onPressed: () => _openForm(event),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ],
            bottom: event == null
                ? null
                : TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      for (final tab in tabs) Tab(text: tab.label),
                    ],
                  ),
          ),
          body: _buildBody(event, tabs),
        ),
      );
    },
  );

  Widget _buildBody(EventModel? event, List<OrganizerEventExtraTab> tabs) {
    if (_provider.hasAccessDenied) {
      return OrganizerAccessDeniedView(
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    if (_provider.hasError) {
      return OrganizerErrorView(
        message: _provider.loadError ?? 'Terjadi kesalahan.',
        onRetry: () => _provider.loadEvent(widget.eventId),
      );
    }
    if (_provider.isLoading || event == null) {
      return const OrganizerLoadingView(message: 'Memuat detail event...');
    }
    return TabBarView(
      children: <Widget>[for (final tab in tabs) tab.builder(context)],
    );
  }

  Widget _sectionCard(String title, Widget child, {Widget? trailing}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
              const SizedBox(height: 2),
              Text(
                (value == null || value.trim().isEmpty) ? '-' : value,
                style: const TextStyle(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildRingkasan(EventModel event) {
    final summary = _provider.summary;
    final period =
        '${core.DateUtils.formatDateTime(event.startDateTime)} - '
        '${core.DateUtils.formatDateTime(event.endDateTime)} '
        '(${OrganizerTimeZones.label(event.timeZone)})';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const OrganizerInfoBanner(
          message:
              'Seluruh angka pada halaman ini berasal dari fixture lokal '
              '(simulasi Tahap 0). Tidak ada order, pembayaran, atau check-in '
              'sungguhan.',
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            OrganizerEventStatusChip(status: event.status),
            const Spacer(),
            if (event.canSubmitForReview)
              FilledButton.tonalIcon(
                key: const Key('summary-submit-button'),
                onPressed: () => _submitForReview(event, resubmit: false),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Ajukan moderasi'),
              )
            else if (event.canResubmit)
              FilledButton.tonalIcon(
                key: const Key('summary-resubmit-button'),
                onPressed: () => _submitForReview(event, resubmit: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Ajukan ulang'),
              )
            else if (event.isPendingReview)
              OutlinedButton.icon(
                key: const Key('summary-simulate-button'),
                onPressed: () => _simulateModeration(event),
                icon: const Icon(Icons.gavel_outlined, size: 18),
                label: const Text('Simulasi moderator'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OrganizerStatGrid(
          tiles: <Widget>[
            OrganizerStatTile(
              label: 'Tiket terjual',
              value: OrganizerFormatters.thousands(summary?.ticketsSold ?? 0),
              icon: Icons.confirmation_number_outlined,
            ),
            OrganizerStatTile(
              label: 'Pesanan pending',
              value: OrganizerFormatters.thousands(summary?.pendingOrders ?? 0),
              icon: Icons.hourglass_empty,
              color: AppTheme.warningColor,
            ),
            OrganizerStatTile(
              label: 'Peserta terdaftar',
              value: OrganizerFormatters.thousands(summary?.participants ?? 0),
              icon: Icons.people_outline,
              color: AppTheme.secondaryColor,
            ),
            OrganizerStatTile(
              label: 'Check-in berhasil',
              value: OrganizerFormatters.thousands(summary?.checkedIn ?? 0),
              icon: Icons.how_to_reg_outlined,
              color: AppTheme.successColor,
            ),
            OrganizerStatTile(
              label: 'Sisa kuota',
              value: OrganizerFormatters.thousands(
                summary?.ticketsRemaining ?? 0,
              ),
              icon: Icons.inventory_2_outlined,
              color: Colors.blueGrey,
            ),
            OrganizerStatTile(
              label: 'Penjualan kotor (demo)',
              value: OrganizerFormatters.rupiah(summary?.grossSales ?? 0),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'Jadwal',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoRow(Icons.schedule, 'Waktu pelaksanaan', period),
              _infoRow(
                Icons.public,
                'Zona waktu',
                OrganizerTimeZones.label(event.timeZone),
              ),
            ],
          ),
        ),
        _sectionCard(
          'Lokasi dan format',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoRow(Icons.category_outlined, 'Format', event.formatLabel),
              if (event.needsPhysicalLocation)
                _infoRow(Icons.place_outlined, 'Alamat', event.location),
              if (event.needsOnlineUrl)
                _infoRow(
                  Icons.videocam_outlined,
                  'Tautan online',
                  event.onlineUrl,
                ),
              _infoRow(Icons.contacts_outlined, 'Kontak', event.contactInfo),
            ],
          ),
        ),
        _sectionCard(
          'Grafik penjualan (demo)',
          OrganizerMiniBarChart(series: _provider.salesPointSeries),
        ),
        _sectionCard(
          'Registrasi publik',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OrganizerQrPlaceholder(seed: event.id),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'QR registrasi (representasi demo)',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          event.registrationUrl,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.registrationUrlIsDemo
                              ? 'Tautan demo: event belum dipublikasikan ke '
                                    'server mana pun.'
                              : 'Tautan publik simulasi untuk event yang sudah '
                                    'disetujui.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _copyLink(event),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Salin tautan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openPreview(event),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Pratinjau publik'),
                  ),
                  if (widget.onRequestReports != null)
                    OutlinedButton.icon(
                      onPressed: widget.onRequestReports,
                      icon: const Icon(Icons.assessment_outlined, size: 18),
                      label: const Text('Laporan event'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (event.canBeDeleted || event.isPublishedLike)
          _sectionCard(
            'Tindakan lanjutan',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (event.canBeDeleted)
                  TextButton.icon(
                    onPressed: () => _deleteEvent(event),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus draft event'),
                  ),
                if (event.isPublishedLike)
                  const Text(
                    'Event yang sudah tayang tidak dapat dihapus dari '
                    'prototipe ini; gunakan pengaturan event bila kebijakan '
                    'pembatalan sudah ditetapkan.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewNoteBox(EventModel event) {
    if (event.reviewNote == null || event.reviewNote!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.feedback_outlined,
                size: 18,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'Catatan revisi moderator',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(event.reviewNote!, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          const Text(
            'Catatan ini berasal dari fixture demo dan tidak dapat diubah oleh '
            'Owner. Status moderasi juga tidak dapat diubah manual.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildInformasi(EventModel event) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildReviewNoteBox(event),
        if (event.isPublishedLike)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: OrganizerInfoBanner(
              message:
                  'Perubahan penting pada event yang sudah tayang dapat '
                  'memerlukan moderasi ulang. Kebijakan detail belum final, '
                  'sehingga status tidak diubah otomatis oleh prototipe ini.',
              color: AppTheme.warningColor,
              icon: Icons.warning_amber_outlined,
            ),
          ),
        _sectionCard(
          'Informasi dasar',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoRow(Icons.title, 'Nama event', event.title),
              _infoRow(Icons.label_outline, 'Kategori', event.category),
              _infoRow(
                Icons.description_outlined,
                'Deskripsi',
                event.description,
              ),
              _infoRow(Icons.image_outlined, 'Poster', event.posterUrl),
              _infoRow(
                Icons.storefront_outlined,
                'Penyelenggara',
                event.organizerName,
              ),
              _infoRow(Icons.contacts_outlined, 'Kontak', event.contactInfo),
            ],
          ),
        ),
        _sectionCard(
          'Jadwal',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoRow(
                Icons.play_circle_outline,
                'Mulai',
                core.DateUtils.formatDateTime(event.startDateTime),
              ),
              _infoRow(
                Icons.stop_circle_outlined,
                'Selesai',
                core.DateUtils.formatDateTime(event.endDateTime),
              ),
              _infoRow(
                Icons.public,
                'Zona waktu',
                OrganizerTimeZones.label(event.timeZone),
              ),
            ],
          ),
        ),
        _sectionCard(
          'Lokasi dan format',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoRow(Icons.category_outlined, 'Format', event.formatLabel),
              _infoRow(Icons.place_outlined, 'Alamat', event.location),
              _infoRow(
                Icons.videocam_outlined,
                'Tautan online',
                event.onlineUrl,
              ),
            ],
          ),
        ),
        _sectionCard(
          'Pengaturan registrasi',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Data peserta yang wajib diisi',
                style: TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final field in event.attendeeFields)
                    Chip(
                      label: Text(
                        OrganizerAttendeeFields.label(field),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.info_outline,
                'Informasi publik',
                event.publicInfo,
              ),
              const Text(
                'Batas waktu pembayaran mengikuti kebijakan platform yang belum '
                'ditetapkan pada prototipe ini.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (event.canBeEdited)
          FilledButton.icon(
            key: const Key('info-edit-button'),
            onPressed: () => _openForm(event),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit informasi event'),
          )
        else
          OrganizerInfoBanner(
            message:
                'Event berstatus ${event.statusLabel} tidak dapat diubah. '
                'Tunggu keputusan moderator atau hubungi admin.',
            color: AppTheme.warningColor,
            icon: Icons.lock_clock,
          ),
      ],
    );
  }

  Widget _buildTicketChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
    ),
  );

  Widget _buildTicketTile(EventModel event, TicketTypeModel type) {
    final period = type.salesStart == null && type.salesEnd == null
        ? 'Tanpa batas periode'
        : '${core.DateUtils.formatDate(type.salesStart)} - '
              '${core.DateUtils.formatDate(type.salesEnd)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        type.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (type.description != null)
                        Text(
                          type.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: type.isActive,
                  onChanged: event.canBeEdited
                      ? (_) => _toggleTicketType(event, type)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              OrganizerFormatters.rupiah(type.price),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _buildTicketChip('Kuota ${type.quota}'),
                _buildTicketChip('Terjual ${type.sold}'),
                _buildTicketChip('Tertahan ${type.held}'),
                _buildTicketChip('Sisa ${type.remainingQuota}'),
                _buildTicketChip(
                  type.maxPerOrder == null
                      ? 'Batas platform'
                      : 'Maks ${type.maxPerOrder}/order',
                ),
                _buildTicketChip(period),
                _buildTicketChip(type.isActive ? 'Aktif' : 'Nonaktif'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => _openTicketForm(event, existing: type),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ubah'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteTicketType(event, type),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiket(EventModel event) {
    final types = _provider.ticketTypes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Kategori tiket (${types.length})',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key('ticket-add-button'),
              onPressed: event.canBeEdited
                  ? () => _openTicketForm(event)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const OrganizerInfoBanner(
          message:
              'Harga pada order lama disimpan sebagai snapshot, sehingga '
              'perubahan harga hanya berlaku untuk order baru. Kuota tidak '
              'boleh lebih kecil dari jumlah terjual + tertahan.',
        ),
        const SizedBox(height: 12),
        if (types.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada kategori tiket',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tambahkan minimal satu kategori agar peserta dapat memesan '
                    'tiket.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: event.canBeEdited
                        ? () => _openTicketForm(event)
                        : null,
                    child: const Text('Tambah kategori tiket'),
                  ),
                ],
              ),
            ),
          )
        else
          for (final type in types) _buildTicketTile(event, type),
      ],
    );
  }
}
