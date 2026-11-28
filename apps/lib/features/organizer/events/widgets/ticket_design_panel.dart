/// Panel desain tiket Organizer (PRD §5).
///
/// Fitur:
///  - unggah desain sendiri (PNG/JPEG) atau gunakan desain default sistem,
///  - pratinjau kanvas yang AKURAT: elemen digambar dengan geometri yang sama
///    dengan PDF (posisi, ukuran huruf, QR),
///  - atur posisi judul, ID tiket, instruksi, dan QR Code lewat slider atau
///    dengan menggeser elemen langsung pada kanvas, sedangkan ukuran huruf
///    diatur lewat input angka (pt) agar nilainya dapat diketik persis,
///  - deteksi tumpang tindih: bounding box setiap elemen terlihat, elemen yang
///    bertabrakan ditandai merah, dan konfigurasi yang bertabrakan tidak dapat
///    disimpan,
///  - kembalikan tata letak ke default sistem,
///  - simpan konfigurasi ke backend; konfigurasi yang sama dipakai saat tiket
///    dirender (PDF & lampiran email).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/event/ticket_design_model.dart';
import '../../../../models/event/ticket_type_model.dart';
import '../../../../services/organizer_events/ticket_design_service.dart';
import 'ticket_canvas_preview.dart';

class TicketDesignPanel extends StatefulWidget {
  const TicketDesignPanel({
    super.key,
    required this.eventId,
    required this.ticketTypes,
    this.eventTitle = 'Nama Event',
    this.initialTicketTypeId,
    this.service,
    this.picker,
    this.onOpenTemplate,
  });

  final String eventId;
  final List<TicketTypeModel> ticketTypes;

  /// Nama acara yang dicetak pada judul tiket (`E-TIKET [NAMA ACARA]`).
  final String eventTitle;

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

  /// Tata letak yang sedang diatur (draft). Belum tentu tersimpan.
  TicketLayoutModel _layout = TicketLayoutModel.defaultLandscape;

  /// Tata letak tersimpan untuk scope aktif (null = belum pernah disimpan).
  TicketLayoutModel? _savedLayout;

  /// Orientasi yang dipilih Organizer tetapi belum disimpan ke backend.
  TicketOrientation? _draftOrientation;

  /// Elemen yang sedang diatur (kontrol posisi & ukuran mengikuti pilihan ini).
  String _selectedElement = TicketElementKey.qr;

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
        _syncFromScope();
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

  TicketPreviewTexts get _texts =>
      TicketPreviewTexts.forEvent(widget.eventTitle);

  TicketLayoutResolution get _resolved =>
      _layout.resolve(orientation: _orientation, texts: _texts);

  /// True bila ada perubahan tata letak yang belum disimpan.
  bool get _dirty => _savedLayout == null || _layout != _savedLayout;

  /// Sinkronkan draft tata letak dengan konfigurasi tersimpan scope aktif.
  void _syncFromScope() {
    final design = _currentDesign;
    _savedLayout = design?.layout;
    _layout = (design?.layout ?? TicketLayoutModel.defaultsFor(_orientation))
        .clamped();
  }

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
    if (mime != null &&
        TicketDesignService.allowedContentTypes.contains(mime)) {
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

  /// Pilih orientasi. Menyimpan ke backend hanya saat Organizer menekan
  /// "Simpan orientasi"; pilihan langsung mengubah template & default tata
  /// letak.
  void _selectOrientation(TicketOrientation orientation) {
    setState(() {
      _draftOrientation = orientation;
      // Desain tersimpan hanya berlaku untuk orientasinya sendiri; tata letak
      // default orientasi baru dipakai bila desain aktif tidak berada pada
      // orientasi ini.
      final design = _currentDesign;
      _layout =
          (design?.hasUploadedFile == true && design!.orientation == orientation
                  ? design.layout
                  : TicketLayoutModel.defaultsFor(orientation))
              .clamped();
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

  /// Simpan konfigurasi tata letak (posisi & ukuran seluruh elemen + QR).
  ///
  /// Backend memakai validasi tumpang tindih yang sama, sehingga konfigurasi
  /// yang tampak valid di pratinjau juga valid untuk PDF.
  Future<void> _saveLayout() async {
    final resolved = _resolved;
    if (!resolved.isValid) {
      _showMessage(
        <String>[
          ...resolved.outOfCanvas,
          ...resolved.conflicts.map((conflict) => conflict.message),
        ].join(' '),
        isError: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.saveLayout(
        eventId: widget.eventId,
        layout: _layout,
        scope: _scope,
        ticketTypeId: _selectedTicketTypeId,
      );
      await _load();
      if (!mounted) return;
      _showMessage(
        'Tata letak tiket disimpan dan dipakai saat tiket diterbitkan '
        '(PDF + lampiran email).',
      );
    } on TicketDesignException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kembalikan tata letak ke default sistem (belum disimpan sampai Organizer
  /// menekan "Simpan tata letak").
  void _resetToDefault() {
    setState(() {
      _layout = TicketLayoutModel.defaultsFor(_orientation);
      _selectedElement = TicketElementKey.qr;
    });
    _showMessage(
      'Tata letak dikembalikan ke default. Tekan simpan untuk menerapkan.',
    );
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
        layout: _layout,
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
    final opened =
        await (widget.onOpenTemplate?.call(url) ??
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

    final resolved = _resolved;
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
              'Desain default sudah siap dipakai. Unggah desain sendiri bila '
              'ingin tampilan berbeda (PNG/JPEG, maksimal 2 MB). Atur posisi & '
              'ukuran tulisan serta QR Code pada pratinjau; konfigurasi yang '
              'disimpan dipakai saat tiket peserta diterbitkan dan dikirim '
              'melalui email.',
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
                      _syncFromScope();
                    }),
            ),
            const SizedBox(height: 12),
            _buildOrientationSelector(),
            const SizedBox(height: 12),
            _buildPreview(resolved),
            const SizedBox(height: 12),
            _buildElementControls(resolved),
            const SizedBox(height: 12),
            _buildConflictPanel(resolved),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('ticket-design-save'),
                  onPressed: _busy || !_dirty || !resolved.isValid
                      ? null
                      : _saveLayout,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Simpan tata letak'),
                ),
                OutlinedButton.icon(
                  key: const Key('ticket-design-reset'),
                  onPressed: _busy ? null : _resetToDefault,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Atur ulang default'),
                ),
                FilledButton.tonalIcon(
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _dirty ? 'Ada perubahan tata letak yang belum disimpan.' : 'Tata letak tersimpan dan dipakai saat tiket diterbitkan.',
                key: const Key('ticket-design-status'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: _dirty ? AppTheme.primaryColor : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pemilih orientasi kanvas tiket (landscape / portrait).
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
                  onSelected: _busy ? null : (_) => _selectOrientation(option),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            orientation.isPortrait
                ? 'Rasio desain portrait: 1 : 1.6 (kanvas 440 x 704 pt, '
                      'contoh file 880 x 1408 px). Desain horizontal akan '
                      'ditolak agar tidak terpotong.'
                : 'Rasio desain landscape: 1.42 : 1 (kanvas 842 x 594 pt, '
                      'contoh file 1684 x 1188 px). Desain vertikal akan '
                      'ditolak agar tidak terpotong.',
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
                          _syncFromScope();
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

  /// Pratinjau kanvas + ringkasan posisi elemen terpilih.
  Widget _buildPreview(TicketLayoutResolution resolved) {
    final design = _currentDesign;
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
          const Text(
            'Pratinjau tiket (sama dengan hasil PDF)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ketuk elemen pada kanvas untuk memilih, lalu geser untuk '
            'memindahkannya. Kotak merah menandakan elemen yang bertabrakan.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('ticket-design-canvas'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TicketCanvasPreview(
              orientation: orientation,
              layout: _layout,
              eventTitle: widget.eventTitle,
              imageUrl: imageUrl,
              selectedKey: _selectedElement,
              onSelected: (key) => setState(() {
                if (key != null) _selectedElement = key;
              }),
              onLayoutChanged: _busy
                  ? null
                  : (value) => setState(() => _layout = value),
            ),
          ),
          const SizedBox(height: 8),
          if (imageUrl == null)
            Text(
              'Belum ada desain unggahan — tiket memakai desain default '
              '${orientation.isPortrait ? 'portrait' : 'landscape'}.',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            )
          else
            Text(
              'Desain aktif: ${design!.contentType.replaceFirst('image/', '').toUpperCase()}'
              '${design.width != null && design.height != null ? ' (${design.width}x${design.height} px)' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          const SizedBox(height: 4),
          Text(
            'Posisi ${TicketElementKey.label(_selectedElement)}: '
            'kiri ${(_elementX(_selectedElement) * 100).round()}%, '
            'atas ${(_elementY(_selectedElement) * 100).round()}%, '
            'ukuran ${_elementSizeLabel(_selectedElement)}',
            key: const Key('ticket-design-qr-summary'),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (resolved.box(_selectedElement)?.truncated == true)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Teks terlalu panjang untuk area ini sehingga dipotong. '
                'Perkecil ukuran huruf atau geser elemen lain.',
                style: TextStyle(fontSize: 11, color: AppTheme.warningColor),
              ),
            ),
        ],
      ),
    );
  }

  double _elementX(String key) =>
      key == TicketElementKey.qr ? _layout.qr.x : _layout.element(key).x;

  double _elementY(String key) =>
      key == TicketElementKey.qr ? _layout.qr.y : _layout.element(key).y;

  String _elementSizeLabel(String key) {
    if (key == TicketElementKey.qr) {
      return 'QR ${(_layout.qr.size * 100).round()}% tinggi kanvas';
    }
    return 'huruf ${_layout.element(key).fontSize.toStringAsFixed(1)} pt';
  }

  /// Ubah satu nilai elemen terpilih tanpa memengaruhi elemen lain.
  void _updateElement({
    double? x,
    double? y,
    double? fontSize,
    double? qrSize,
  }) {
    setState(() {
      final key = _selectedElement;
      if (key == TicketElementKey.qr) {
        _layout = _layout.copyWith(
          qr: _layout.qr.copyWith(x: x, y: y, size: qrSize).clamped(),
        );
        return;
      }
      _layout = _layout.withElement(
        key,
        _layout.element(key).copyWith(x: x, y: y, fontSize: fontSize).clamped(),
      );
    });
  }

  /// Slider & tombol untuk elemen terpilih.
  Widget _buildElementControls(TicketLayoutResolution resolved) {
    final key = _selectedElement;
    final isQr = key == TicketElementKey.qr;
    final element = isQr ? null : _layout.element(key);
    final x = _elementX(key);
    final y = _elementY(key);
    return Container(
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
            'Atur elemen',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final option in <String>[
                TicketElementKey.title,
                TicketElementKey.ticketId,
                TicketElementKey.instruction,
                TicketElementKey.qr,
              ])
                ChoiceChip(
                  key: Key('ticket-design-element-$option'),
                  label: Text(TicketElementKey.label(option)),
                  selected: _selectedElement == option,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _selectedElement = option),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Posisi horizontal ${TicketElementKey.label(key)}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          Slider(
            key: Key('ticket-design-$key-x'),
            value: x.clamp(0, 0.95),
            max: 0.95,
            divisions: 95,
            label: '${(x * 100).round()}%',
            onChanged: _busy ? null : (value) => _updateElement(x: value),
          ),
          Text(
            'Posisi vertikal ${TicketElementKey.label(key)}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          Slider(
            key: Key('ticket-design-$key-y'),
            value: y.clamp(0, 0.95),
            max: 0.95,
            divisions: 95,
            label: '${(y * 100).round()}%',
            onChanged: _busy ? null : (value) => _updateElement(y: value),
          ),

          _buildSizeControl(element),
          Text(
            'Elemen di dalam kanvas: '
            '${resolved.outOfCanvas.isEmpty ? 'ya' : 'tidak'} · '
            'Tumpang tindih: '
            '${resolved.conflicts.isEmpty ? 'tidak ada' : '${resolved.conflicts.length} terdeteksi'}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  /// Kontrol ukuran: QR (persen tinggi kanvas + tombol perbesar/perkecil) atau
  /// ukuran huruf elemen teks (pt) lewat input angka.
  Widget _buildSizeControl(TicketTextElement? element) {
    final isQr = _selectedElement == TicketElementKey.qr;
    if (isQr) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Ukuran QR Code',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
              IconButton(
                key: const Key('ticket-design-qr-smaller'),
                tooltip: 'Perkecil QR',
                onPressed: _busy
                    ? null
                    : () => _updateElement(qrSize: _layout.qr.size - 0.02),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              IconButton(
                key: const Key('ticket-design-qr-larger'),
                tooltip: 'Perbesar QR',
                onPressed: _busy
                    ? null
                    : () => _updateElement(qrSize: _layout.qr.size + 0.02),
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
            ],
          ),
          Slider(
            key: const Key('ticket-design-qr-size'),
            value: _layout.qr.size,
            // Batas sama dengan backend (`QR_PLACEMENT_LIMITS`): 15%-60%
            // tinggi kanvas. Di atas 60% QR menutupi hampir seluruh desain.
            min: TicketQrPlacement.minSize,
            max: TicketQrPlacement.maxSize,
            divisions: 45,
            label: '${(_layout.qr.size * 100).round()}%',
            onChanged: _busy ? null : (value) => _updateElement(qrSize: value),
          ),
        ],
      );
    }
    return _FontSizeField(
      key: ValueKey<String>('font-size-$_selectedElement'),
      elementKey: _selectedElement,
      value: element!.fontSize,
      enabled: !_busy,
      onChanged: (value) => _updateElement(fontSize: value),
    );
  }

  /// Daftar peringatan tumpang tindih (indikator visual + alasan tombol simpan
  /// dinonaktifkan).
  Widget _buildConflictPanel(TicketLayoutResolution resolved) {
    final conflicts = resolved.conflicts;
    final outOfCanvas = resolved.outOfCanvas;
    final valid = conflicts.isEmpty && outOfCanvas.isEmpty;
    return Container(
      key: const Key('ticket-design-conflicts'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: valid ? AppTheme.softGreenBg : AppTheme.softRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valid ? AppTheme.successColor : AppTheme.errorColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                valid
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                size: 18,
                color: valid ? AppTheme.successColor : AppTheme.errorColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  valid
                      ? 'Semua elemen terlihat dan tidak bertumpuk.'
                      : 'Perbaiki tata letak sebelum menyimpan:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valid ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          for (final message in outOfCanvas)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                '• $message',
                style: const TextStyle(fontSize: 11.5, color: Colors.black87),
              ),
            ),
          for (final conflict in conflicts)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                '• ${conflict.message}',
                style: const TextStyle(fontSize: 11.5, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }
}

/// Input angka untuk ukuran huruf elemen teks (pt).
///
/// Menggantikan slider agar Organizer dapat mengetik ukuran persis (mis. 42 pt)
/// tanpa menyeret dan menebak nilai. Nilai selalu dijaga pada batas backend
/// ([TicketLayoutLimits.minFontSize]–[TicketLayoutLimits.maxFontSize]).
///
/// Kemudahan yang disediakan:
///  - kolom angka dengan papan ketik numerik (koma/titik desimal diterima),
///  - tombol − / + untuk menyesuaikan 1 pt,
///  - pilihan cepat ukuran yang umum dipakai.
class _FontSizeField extends StatefulWidget {
  const _FontSizeField({
    super.key,
    required this.elementKey,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String elementKey;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<_FontSizeField> createState() => _FontSizeFieldState();
}

class _FontSizeFieldState extends State<_FontSizeField> {
  /// Langkah tombol − / + dalam pt.
  static const double _step = 1;

  /// Ukuran yang sering dipakai (judul 50 pt & teks 30 pt termasuk di sini).
  static const List<double> _presets = <double>[
    12,
    16,
    20,
    24,
    30,
    36,
    40,
    50,
    64,
    80,
  ];

  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focusNode = FocusNode();
  String? _error;

  static double get _min => TicketLayoutLimits.minFontSize;
  static double get _max => TicketLayoutLimits.maxFontSize;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(_FontSizeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sinkronkan nilai dari luar (mis. "Atur ulang default") selama pengguna
    // tidak sedang mengetik agar teks yang diketik tidak tertimpa.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Tampilkan angka tanpa desimal bila bulat, satu desimal bila perlu.
  static String _format(double value) {
    final rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  /// Terima angka dengan pemisah desimal koma maupun titik.
  static double? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite) return null;
    return value;
  }

  /// Terapkan nilai yang sudah dibulatkan ke 0,1 pt dan dijaga di dalam batas.
  void _apply(double value) {
    final normalized = (value.clamp(_min, _max) * 10).roundToDouble() / 10;
    final text = _format(normalized);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (normalized != widget.value) widget.onChanged(normalized);
  }

  /// Saat mengetik: terapkan langsung bila valid agar pratinjau ikut berubah.
  void _handleChanged(String raw) {
    final parsed = _parse(raw);
    if (parsed == null) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    // Nilai di luar batas baru dirapikan saat pengguna selesai mengetik,
    // supaya mengetik "1" menuju "15" tidak langsung dianggap salah.
    if (parsed < _min || parsed > _max) return;
    if (_error != null) setState(() => _error = null);
    final normalized = (parsed * 10).roundToDouble() / 10;
    if (normalized != widget.value) widget.onChanged(normalized);
  }

  /// Rapikan nilai saat Enter atau fokus berpindah: kosong/tidak valid
  /// dikembalikan ke nilai terakhir, di luar batas dipotong ke batas.
  void _commit() {
    if (!mounted) return;
    final parsed = _parse(_controller.text);
    if (parsed == null) {
      setState(() => _error = null);
      _apply(widget.value);
      return;
    }
    if (parsed < _min || parsed > _max) {
      _apply(parsed);
      setState(
        () => _error =
            'Ukuran disesuaikan ke batas ${_format(_min)}–${_format(_max)} pt.',
      );
      return;
    }
    // Nilai valid: pesan batas (bila ada) sudah dibersihkan saat pengguna
    // mengetik. Jangan dihapus di sini agar commit ganda (Enter + fokus
    // berpindah) tidak menghilangkan informasi bahwa nilai tadi dipotong.
    _apply(parsed);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _stepBy(double delta) {
    setState(() => _error = null);
    _apply(widget.value + delta);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final key = widget.elementKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Ukuran huruf ${TicketElementKey.label(key)}',
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconButton(
              key: Key('ticket-design-$key-font-size-decrease'),
              tooltip: 'Perkecil 1 pt',
              onPressed: !enabled || widget.value <= _min
                  ? null
                  : () => _stepBy(-_step),
              icon: const Icon(Icons.remove_circle_outline, size: 22),
            ),
            Expanded(
              child: TextField(
                key: Key('ticket-design-$key-font-size'),
                controller: _controller,
                focusNode: _focusNode,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Ukuran',
                  suffixText: 'pt',
                  helperText:
                      'Ketik angka ${_format(_min)}–${_format(_max)}, mis. 42',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: enabled ? _handleChanged : null,
                onSubmitted: enabled ? (_) => _commit() : null,
                onTapOutside: enabled ? (_) => _focusNode.unfocus() : null,
              ),
            ),
            IconButton(
              key: Key('ticket-design-$key-font-size-increase'),
              tooltip: 'Perbesar 1 pt',
              onPressed: !enabled || widget.value >= _max
                  ? null
                  : () => _stepBy(_step),
              icon: const Icon(Icons.add_circle_outline, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Pilihan cepat (pt)',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final size in _presets)
              ChoiceChip(
                key: Key(
                  'ticket-design-$key-font-size-preset-${_format(size)}',
                ),
                label: Text(_format(size)),
                selected: (widget.value - size).abs() < 0.05,
                onSelected: enabled
                    ? (_) => _stepBy(size - widget.value)
                    : null,
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11.5),
              ),
          ],
        ),
      ],
    );
  }
}
