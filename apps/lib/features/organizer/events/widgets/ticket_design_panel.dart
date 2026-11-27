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
    this.initialTicketTypeId,
    this.service,
    this.picker,
    this.onOpenTemplate,
  });

  final String eventId;
  final List<TicketTypeModel> ticketTypes;

  /// Scope kategori tiket awal saat panel dibuka (opsional).
  final String? initialTicketTypeId;

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

  /// Orientasi yang dipilih Organizer tetapi belum disimpan ke backend.
  TicketOrientation? _draftOrientation;

  @override
  void initState() {
    super.initState();
    _selectedTicketTypeId = widget.initialTicketTypeId;
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
        _draftOrientation = null;
        final effective = state.orientationFor(_selectedTicketTypeId);
        // Posisi QR mengikuti orientasi desain aktif, bukan default landscape.
        final design = _selectedTicketTypeId == null
            ? state.eventDesign
            : state.ticketTypeDesigns[_selectedTicketTypeId];
        _qr = design?.hasUploadedFile == true &&
                design!.orientation == effective
            ? design.qr
            : TicketDesignModel.defaultQrFor(effective);
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

  /// Orientasi yang sedang dipilih/ditampilkan untuk scope aktif.
  TicketOrientation get _orientation =>
      _draftOrientation ?? _state.orientationFor(_selectedTicketTypeId);

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

  /// Pilih orientasi. Menyimpan ke backend hanya saat penyelenggara menekan
  /// "Simpan orientasi"; pilihan langsung mengubah template & default QR.
  void _selectOrientation(TicketOrientation orientation) {
    setState(() {
      _draftOrientation = orientation;
      _qr = TicketDesignModel.defaultQrFor(orientation);
    });
  }

  Future<void> _saveOrientation() async {
    final orientation = _orientation;
    setState(() => _busy = true);
    try {
      await _service.saveOrientation(
        eventId: widget.eventId,
        orientation: orientation,
        scope: _scope,
        ticketTypeId: _selectedTicketTypeId,
      );
      await _load();
      if (!mounted) return;
      _showMessage(
        'Orientasi ${orientation.label} disimpan dan dipakai saat tiket '
        'diterbitkan.',
      );
    } on TicketDesignException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        orientation: _orientation,
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
    final url = TicketDesignService.templateUrl(
      format,
      orientation: _orientation,
    );
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
                  : (value) => setState(() {
                      _selectedTicketTypeId = value;
                      _draftOrientation = null;
                      final effective = _state.orientationFor(value);
                      final design = value == null
                          ? _state.eventDesign
                          : _state.ticketTypeDesigns[value];
                      _qr =
                          design?.hasUploadedFile == true &&
                              design!.orientation == effective
                          ? design.qr
                          : TicketDesignModel.defaultQrFor(effective);
                    }),
            ),
            const SizedBox(height: 12),
            _buildOrientationSelector(),
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
                if (_currentDesign?.hasUploadedFile == true)
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

  /// Pemilih orientasi kanvas tiket (landscape / portrait).
  ///
  /// Orientasi harus dipilih SEBELUM mengunggah desain karena rasio file
  /// mengikuti kanvas; template PDF/PNG yang diunduh juga mengikuti pilihan ini.
  Widget _buildOrientationSelector() {
    final orientation = _orientation;
    final saved = _state.orientationFor(_selectedTicketTypeId);
    final pending = _draftOrientation != null && _draftOrientation != saved;
    return Container(
      key: const Key('ticket-design-orientation'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Orientasi tiket',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pilih orientasi sebelum mengunggah desain. Template dan tiket PDF '
            'peserta akan mengikuti orientasi ini.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final option in TicketOrientation.values)
                ChoiceChip(
                  key: Key('ticket-design-orientation-${option.value}'),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        option.isPortrait
                            ? Icons.crop_portrait
                            : Icons.crop_landscape,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(option.label),
                    ],
                  ),
                  selected: orientation == option,
                  onSelected: _busy
                      ? null
                      : (_) => _selectOrientation(option),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            orientation.isPortrait
                ? 'Rasio desain portrait: 1 : 1.6 (contoh 440 x 704 px). '
                      'Desain horizontal akan ditolak agar tidak terpotong.'
                : 'Rasio desain landscape: 2.5 : 1 (contoh 1080 x 432 px). '
                      'Desain vertikal akan ditolak agar tidak terpotong.',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          if (pending) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('ticket-design-orientation-save'),
                  onPressed: _busy ? null : _saveOrientation,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan orientasi'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _draftOrientation = null;
                          _qr = TicketDesignModel.defaultQrFor(saved);
                        }),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Orientasi tersimpan: ${saved.label}',
                key: const Key('ticket-design-orientation-saved'),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(TicketDesignModel? design) {
    final imageUrl = design == null || !design.hasUploadedFile
        ? null
        : (design.url ?? AppConfig.mediaUrl(design.filePath));
    final orientation = _orientation;
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
          // Kanvas pratinjau memakai rasio orientasi terpilih, sehingga
          // penyelenggara melihat proporsi tiket yang sebenarnya.
          AspectRatio(
            aspectRatio: orientation.widthToHeightRatio,
            child: Container(
              key: const Key('ticket-design-canvas'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      key: const Key('ticket-design-preview'),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Pratinjau desain tidak dapat dimuat.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Belum ada desain unggahan — tiket memakai desain '
                          'default ${orientation.isPortrait ? 'portrait' : 'landscape'}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  // Penanda area QR: posisi fraksi 0..1 dari kanvas.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final side =
                          _qr.size * constraints.maxHeight;
                      return Stack(
                        children: <Widget>[
                          Positioned(
                            key: const Key('ticket-design-qr-marker'),
                            left: _qr.x * constraints.maxWidth,
                            top: _qr.y * constraints.maxHeight,
                            child: Container(
                              width: side,
                              height: side,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 1.4,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Text(
                                    'AREA QR',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
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
          if (design != null && design.hasUploadedFile)
            Text(
              'Desain aktif: ${design.contentType.replaceFirst('image/', '').toUpperCase()}'
              '${design.width != null && design.height != null ? ' (${design.width}x${design.height} px)' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
        ],
      ),
    );
  }
}
