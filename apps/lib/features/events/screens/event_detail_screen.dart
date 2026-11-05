import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/event_provider.dart';
import '../../registration/screens/registration_screen.dart';

/// Event detail screen displaying full event info and ticket options (PRD section 7.2 C).
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventProvider _provider = EventProvider.instance;
  late String _effectiveEventId;

  @override
  void initState() {
    super.initState();
    _effectiveEventId = widget.eventId ?? 'evt-001';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If passed through route arguments, prioritize that
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is String && routeArg.isNotEmpty) {
        _effectiveEventId = routeArg;
      }
      _provider.loadEvent(_effectiveEventId);
    });
  }

  String _formatCurrency(double amount) {
    if (amount <= 0) return 'Gratis';
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final event = _provider.selectedEvent;
        final ticketTypes = _provider.ticketTypes;

        return Scaffold(
          body: _provider.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat detail event...'),
                    ],
                  ),
                )
              : _provider.error != null || event == null
                  ? Scaffold(
                      appBar: AppBar(title: const Text('Detail Event')),
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text(
                                _provider.error ?? 'Event tidak ditemukan.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _provider.loadEvent(_effectiveEventId),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Sliver AppBar with Poster
                        SliverAppBar(
                          expandedHeight: 240,
                          pinned: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (event.posterUrl != null && event.posterUrl!.isNotEmpty)
                                  Image.network(
                                    event.posterUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildHeaderFallback(),
                                  )
                                else
                                  _buildHeaderFallback(),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Colors.black87],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Event Main Content
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category and Event Type Badges
                                Row(
                                  children: [
                                    if (event.category != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          event.category!,
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        event.eventType.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Title
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Date Card
                                _buildInfoTile(
                                  icon: Icons.calendar_today,
                                  iconColor: Colors.indigo,
                                  title: 'Waktu Pelaksanaan',
                                  subtitle:
                                      '${app_date.DateUtils.formatDateTime(event.startDateTime)} - ${app_date.DateUtils.formatDateTime(event.endDateTime)}',
                                ),
                                const SizedBox(height: 12),

                                // Location Card
                                _buildInfoTile(
                                  icon: Icons.location_on,
                                  iconColor: Colors.pink,
                                  title: 'Lokasi / Platform',
                                  subtitle: event.location ??
                                      (event.onlineUrl ?? 'Akan diumumkan oleh penyelenggara'),
                                ),
                                const SizedBox(height: 12),

                                // Contact Info
                                if (event.contactInfo != null && event.contactInfo!.isNotEmpty)
                                  _buildInfoTile(
                                    icon: Icons.contact_support_outlined,
                                    iconColor: Colors.teal,
                                    title: 'Kontak Penyelenggara',
                                    subtitle: event.contactInfo!,
                                  ),

                                const Divider(height: 36),

                                // Description
                                const Text(
                                  'Tentang Acara Ini',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  event.description ?? 'Belum ada deskripsi untuk acara ini.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.grey.shade800,
                                  ),
                                ),

                                const Divider(height: 36),

                                // Ticket Types Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Kategori Tiket',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${ticketTypes.length} Kategori',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (ticketTypes.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Belum ada kategori tiket untuk acara ini.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  )
                                else
                                  ...ticketTypes.map((tt) => _buildTicketTypeCard(tt)),

                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          bottomNavigationBar: event != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        offset: const Offset(0, -3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai dari',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              Text(
                                ticketTypes.isNotEmpty
                                    ? _formatCurrency(ticketTypes.map((t) => t.price).reduce((a, b) => a < b ? a : b))
                                    : 'Gratis',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegistrationScreen(event: event),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Pesan Tiket',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketTypeCard(TicketTypeModel ticketType) {
    final isSoldOut = ticketType.isSoldOut;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSoldOut ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSoldOut ? Colors.grey.shade300 : AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ticketType.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSoldOut ? Colors.grey.shade600 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSoldOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HABIS',
                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                if (ticketType.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ticketType.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  isSoldOut ? 'Kuota telah habis terjual' : 'Sisa kuota: ${ticketType.availableQuota} tiket',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSoldOut ? Colors.grey : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(ticketType.price),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSoldOut ? Colors.grey : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.deepPurple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.confirmation_number, size: 72, color: Colors.white54),
      ),
    );
  }
}
