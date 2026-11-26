/// Panel desain tiket Organizer (PRD §5).
///
/// Fitur yang disediakan:
///  - unduh template PDF/PNG (ukuran & penanda posisi QR),
///  - unggah desain sendiri untuk seluruh event (default) atau khusus satu
///    kategori tiket,
///  - atur posisi & ukuran QR pada kanvas desain,
///  - hapus desain agar tiket kembali memakai desain default sistem.
///
/// Semua perubahan disimpan ke backend dan dipakai saat tiket diterbitkan.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/event/ticket_design_model.dart';
import '../../../../models/event/ticket_type_model.dart';
import '../../../../services/organizer_events/ticket_design_service.dart';

class TicketDesignPanel extends StatefulWidget {
  const TicketDesignPanel({
    super.key,
    required this.eventId,
    required this.ticketTypes,
    this.service,
    this.picker,
    this.onOpenTemplate,
  });

  final String eventId;
  final List<TicketTypeModel> ticketTypes;

  /// Dapat diganti pada test agar tidak memanggil HTTP.
  final TicketDesignService? service;

  /// Dapat diganti pada test agar tidak membuka pemilih file.
  final ImagePicker? picker;

  /// Kanal opsional untuk membuka template (default: link launcher).
  final Future<bool> Function(String url)? onOpenTemplate;

  @override
  State<TicketDesignPanel> createState() => _TicketDesignPanelState();
}

class _TicketDesignPanelState extends State<TicketDesignPanel> {
  late final TicketDesignService _service =
      widget.service ?? TicketDesignService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  TicketDesignState _state = const TicketDesignState();
  String? _selectedTicketTypeId;
  TicketQrPlacement _qr = TicketDesignModel.defaultQr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final state = await _service.load(widget.eventId);
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } on TicketDesignException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    }
  }

  String get _scope => _selectedTicketTypeId == null ? 'event' : 'ticket_type';

  TicketDesignModel? get _currentDesign => _selectedTicketTypeId == null
      ? _state.eventDesign
      : _state.ticketTypeDesigns[_selectedTicketTypeId];

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
      ),
    );
  }

  static String? _resolveContentType(XFile file, List<int> bytes) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && TicketDesignService.allowedContentTypes.contains(mime)) {
      return mime;
    }
    // Fallback signature PNG / JPEG (nama file web kadang tanpa ekstensi).
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return 'image/png';
    }
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    return null;
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final contentType = _resolveContentType(picked, bytes);
    if (contentType == null) {
      _showMessage('Format desain harus PNG atau JPEG.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await _service.upload(
        eventId: widget.eventId,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
        scope: _scope,
        ticketTypeId: _selectedTicketTypeId,
        qr: _qr,
      );
      await _load();
      if (!mounted) return;
      _showMessage(
        _selectedTicketTypeId == null
            ? 'Desain tiket event tersimpan dan dipakai saat tiket diterbitkan.'
            : 'Desain tiket kategori tersimpan dan dipakai saat tiket diterbitkan.',
      );
    } on TicketDesignException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDesign() async {
    setState(() => _busy = true);
    try {
      await _service.remove(
        eventId: widget.eventId,
        scope: _scope,
        ticketTypeId: _selectedTicketTypeId,
      );
      await _load();
      if (!mounted) return;
      _showMessage('Desain dihapus. Tiket memakai desain default sistem.');
    } on TicketDesignException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTemplate(String format) async {
    final url = TicketDesignService.templateUrl(format);
    final opened = await (widget.onOpenTemplate?.call(url) ??
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
    if (!opened && mounted) {
      _showMessage(
        'Template tidak dapat dibuka otomatis. Buka manual: $url',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _loadError!,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      key: const Key('ticket-design-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Desain Tiket',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Unggah desain sendiri (PNG/JPEG, maksimal 2 MB) atau gunakan '
              'desain default. Desain yang tersimpan dipakai saat tiket '
              'peserta diterbitkan dan dikirim melalui email.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('ticket-design-scope'),
              initialValue: _selectedTicketTypeId,
              decoration: const InputDecoration(
                labelText: 'Berlaku untuk',
                isDense: true,
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Seluruh event (desain default)'),
                ),
                for (final type in widget.ticketTypes)
                  DropdownMenuItem<String?>(
                    value: type.id,
                    child: Text('Kategori: ${type.name}'),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _selectedTicketTypeId = value),
            ),
            const SizedBox(height: 12),
            _buildPreview(_currentDesign),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('ticket-design-upload'),
                  onPressed: _busy ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Unggah desain'),
                ),
                OutlinedButton.icon(
                  key: const Key('ticket-design-template-pdf'),
                  onPressed: _busy ? null : () => _openTemplate('pdf'),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Template PDF'),
                ),
                OutlinedButton.icon(
                  key: const Key('ticket-design-template-png'),
                  onPressed: _busy ? null : () => _openTemplate('png'),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Template PNG'),
                ),
                if (_currentDesign != null)
                  TextButton.icon(
                    key: const Key('ticket-design-remove'),
                    onPressed: _busy ? null : _removeDesign,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus desain'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(TicketDesignModel? design) {
    final imageUrl = design == null
        ? null
        : (design.url ?? AppConfig.mediaUrl(design.filePath));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (imageUrl == null || imageUrl.isEmpty)
            Row(
              children: <Widget>[
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Belum ada desain unggahan — tiket memakai desain default.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl,
                key: const Key('ticket-design-preview'),
                height: 120,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Pratinjau desain tidak dapat dimuat.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Posisi QR: kiri ${(_qr.x * 100).round()}%, '
            'atas ${(_qr.y * 100).round()}%, '
            'ukuran ${(_qr.size * 100).round()}% (dari tinggi kanvas).',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            'Posisi X QR',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          Slider(
            key: const Key('ticket-design-qr-x'),
            value: _qr.x,
            min: 0,
            max: 0.95,
            divisions: 19,
            label: '${(_qr.x * 100).round()}%',
            onChanged: _busy
                ? null
                : (value) => setState(() => _qr = _qr.copyWith(x: value)),
          ),
          const Text(
            'Ukuran QR',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          Slider(
            key: const Key('ticket-design-qr-size'),
            value: _qr.size,
            min: 0.15,
            max: 0.9,
            divisions: 15,
            label: '${(_qr.size * 100).round()}%',
            onChanged: _busy
                ? null
                : (value) => setState(() => _qr = _qr.copyWith(size: value)),
          ),
          if (design != null)
            Text(
              'Desain aktif: ${design.contentType.replaceFirst('image/', '').toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
        ],
      ),
    );
  }
}
