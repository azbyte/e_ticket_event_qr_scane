import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as core;
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/public_event/public_event_service.dart';
import '../../organizer/events/widgets/organizer_summary_widgets.dart';

/// Landing publik event — dibuka guest tanpa login lewat tautan
/// `/e/{eventId}` (PRD §6.1, §7; D1-4).
class PublicEventScreen extends StatefulWidget {
  const PublicEventScreen({super.key, required this.eventId, this.service});

  final String eventId;

  /// Dapat diganti pada test untuk menguji seluruh state tanpa HTTP.
  final PublicEventService? service;

  @override
  State<PublicEventScreen> createState() => _PublicEventScreenState();
}

enum _PublicEventStatus { loading, ready, unavailable, error }

class _PublicEventScreenState extends State<PublicEventScreen> {
  late final PublicEventService _service =
      widget.service ?? PublicEventService();

  _PublicEventStatus _status = _PublicEventStatus.loading;
  PublicEventData? _data;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = _PublicEventStatus.loading;
      _message = null;
    });
    try {
      final data = await _service.loadEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = _PublicEventStatus.ready;
      });
    } on PublicEventUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _status = _PublicEventStatus.unavailable;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString();
        _status = _PublicEventStatus.error;
      });
    }
  }

  void _openRegistration(EventModel event) {
    Navigator.of(context).pushNamed(AppRoutes.publicEventRegisterPath(event.id));
  }

  String _priceLabel(double value) =>
      value <= 0 ? 'Gratis' : OrganizerFormatters.rupiah(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Event'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _status == _PublicEventStatus.ready
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _PublicEventStatus.loading:
        return const Center(
          key: Key('public-event-loading'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat informasi event...'),
            ],
          ),
        );
      case _PublicEventStatus.unavailable:
        return _buildMessageState(
          key: const Key('public-event-unavailable'),
          icon: Icons.event_busy_outlined,
          title: 'Event tidak tersedia',
          message:
              _message ??
              'Event belum dipublikasikan atau sudah tidak tersedia.',
        );
      case _PublicEventStatus.error:
        return _buildMessageState(
          key: const Key('public-event-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat event',
          message: _message ?? 'Periksa koneksi lalu coba lagi.',
          color: AppTheme.errorColor,
        );
      case _PublicEventStatus.ready:
        return _buildContent(_data!);
    }
  }

  Widget _buildMessageState({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    Color? color,
  }) => Center(
    key: key,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 64, color: color ?? Colors.grey.shade500),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
        ],
      ),
    ),
  );

  Widget _buildContent(PublicEventData data) {
    final event = data.event;
    final now = DateTime.now();
    final sellable = data.sellableTypes(now);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const Key('public-event-content'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            _buildHero(event),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (event.category != null)
                  _badge(event.category!, AppTheme.primaryColor),
                _badge(
                  event.eventType.toUpperCase(),
                  Colors.grey.shade700,
                  background: Colors.grey.shade200,
                ),
                if (event.organizerName != null)
                  _badge(event.organizerName!, AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            _infoTile(
              icon: Icons.calendar_today,
              color: AppTheme.primaryColor,
              title: 'Waktu pelaksanaan',
              subtitle:
                  '${core.DateUtils.formatDateTime(event.startDateTime)} - '
                  '${core.DateUtils.formatDateTime(event.endDateTime)}',
            ),
            const SizedBox(height: 10),
            _infoTile(
              icon: Icons.location_on,
              color: AppTheme.primaryDarkColor,
              title: 'Lokasi / platform',
              subtitle:
                  event.location ??
                  event.onlineUrl ??
                  'Akan diumumkan oleh penyelenggara',
            ),
            if (event.contactInfo != null &&
                event.contactInfo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoTile(
                icon: Icons.contact_support_outlined,
                color: AppTheme.successColor,
                title: 'Kontak penyelenggara',
                subtitle: event.contactInfo!,
              ),
            ],
            const Divider(height: 36),
            const Text(
              'Tentang acara ini',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              event.description?.trim().isNotEmpty == true
                  ? event.description!
                  : 'Belum ada deskripsi untuk acara ini.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade800,
              ),
            ),
            if (event.publicInfo?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.publicInfo!,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
            const Divider(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Kategori tiket',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${data.ticketTypes.length} kategori',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.ticketTypes.isEmpty)
              Container(
                key: const Key('public-event-empty-tickets'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum ada kategori tiket untuk acara ini.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...data.ticketTypes.map((type) => _ticketCard(type, now)),
            if (data.ticketTypes.isNotEmpty && sellable.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Semua kategori sedang tidak dapat dipesan (habis atau di luar '
                'periode penjualan).',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildHero(EventModel event) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 200,
        child: event.posterUrl != null && event.posterUrl!.isNotEmpty
            ? Image.network(
                event.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _heroFallback(),
              )
            : _heroFallback(),
      ),
    );
  }

  Widget _heroFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.confirmation_number, size: 64, color: Colors.white54),
    ),
  );

  Widget _badge(String label, Color color, {Color? background}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 11.5,
      ),
    ),
  );

  Widget _infoTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 17,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );


  Widget _ticketCard(TicketTypeModel type, DateTime now) {
    final available = type.isSellableAt(now);
    return Container(
      key: Key('public-ticket-${type.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: available ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: available
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  type.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: available ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                if (type.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    type.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  available
                      ? 'Sisa kuota: ${type.remainingQuota} tiket'
                      : 'Tidak tersedia untuk dipesan',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: available ? Colors.green.shade700 : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _priceLabel(type.price),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: available ? AppTheme.primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final data = _data!;
    final sellable = data.sellableTypes(DateTime.now());
    final enabled = sellable.isNotEmpty;
    final cheapest = data.ticketTypes.isEmpty
        ? 0.0
        : data.ticketTypes
              .map((type) => type.price)
              .reduce((left, right) => left < right ? left : right);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mulai dari',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _priceLabel(cheapest),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              key: const Key('public-event-register-button'),
              onPressed: enabled ? () => _openRegistration(data.event) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                enabled ? 'Daftar Sekarang' : 'Tiket tidak tersedia',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
