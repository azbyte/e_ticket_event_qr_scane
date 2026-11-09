/// Form tambah/ubah kategori tiket (PRD 5.4 D, 5.5.3).
///
/// Aturan kuota: `terjual + tertahan` tidak boleh melebihi kuota baru sehingga
/// order historis tetap terlindungi. Penghapusan kategori bertransaksi ditolak
/// di repository; di sini hanya disediakan tombol nonaktifkan.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as core;
import '../../../../models/event/ticket_type_model.dart';
import '../../../../providers/event_provider.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';
import '../../../../services/organizer_events/organizer_event_validators.dart';
import '../widgets/organizer_feedback_view.dart';

class OrganizerTicketTypeFormScreen extends StatefulWidget {
  const OrganizerTicketTypeFormScreen({
    super.key,
    required this.provider,
    required this.eventId,
    this.initial,
  });

  final EventProvider provider;
  final String eventId;

  /// Null berarti membuat kategori baru.
  final TicketTypeModel? initial;

  @override
  State<OrganizerTicketTypeFormScreen> createState() =>
      _OrganizerTicketTypeFormScreenState();
}

class _OrganizerTicketTypeFormScreenState
    extends State<OrganizerTicketTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _quota = TextEditingController();
  final _maxPerOrder = TextEditingController();

  DateTime? _salesStart;
  DateTime? _salesEnd;
  bool _isActive = true;
  bool _saving = false;
  Map<String, String> _fieldErrors = const <String, String>{};

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _name.text = initial.name;
      _description.text = initial.description ?? '';
      _price.text = _formatNumber(initial.price);
      _quota.text = initial.quota.toString();
      _maxPerOrder.text = initial.maxPerOrder?.toString() ?? '';
      _salesStart = initial.salesStart;
      _salesEnd = initial.salesEnd;
      _isActive = initial.isActive;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _quota.dispose();
    _maxPerOrder.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  Future<void> _pickPeriod({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _salesStart : _salesEnd) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    setState(() {
      if (isStart) {
        _salesStart = combined;
      } else {
        _salesEnd = combined;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final draft = OrganizerTicketTypeDraft(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      price: double.tryParse(_price.text.trim()) ?? 0,
      quota: int.tryParse(_quota.text.trim()) ?? 0,
      maxPerOrder: _maxPerOrder.text.trim().isEmpty
          ? null
          : int.tryParse(_maxPerOrder.text.trim()),
      salesStart: _salesStart,
      salesEnd: _salesEnd,
      isActive: _isActive,
    );

    final businessErrors = OrganizerEventValidators.validateTicketTypeDraft(
      draft,
      sold: widget.initial?.sold ?? 0,
      held: widget.initial?.held ?? 0,
    );
    if (businessErrors.isNotEmpty) {
      setState(() => _fieldErrors = businessErrors);
      return;
    }
    setState(() => _fieldErrors = const <String, String>{});

    setState(() => _saving = true);
    final saved = await widget.provider.saveTicketType(
      eventId: widget.eventId,
      draft: draft,
      ticketTypeId: widget.initial?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved == null) {
      final errors = widget.provider.fieldErrors;
      setState(() => _fieldErrors = errors);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.actionError ?? 'Kategori tiket gagal disimpan.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Kategori "${saved.name}" diperbarui.'
              : 'Kategori "${saved.name}" ditambahkan.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Harga wajib diisi (isi 0 untuk tiket gratis).';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Harga harus berupa angka.';
    if (parsed < 0) return 'Harga tidak boleh negatif.';
    return null;
  }

  String? _validateQuota(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Kuota wajib diisi.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Kuota harus berupa angka bulat.';
    return OrganizerEventValidators.validateQuotaChange(
      newQuota: parsed,
      sold: widget.initial?.sold ?? 0,
      held: widget.initial?.held ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Ubah Kategori Tiket' : 'Tambah Kategori Tiket',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            if (initial != null)
              OrganizerInfoBanner(
                message: 'Terjual ${initial.sold} • Tertahan ${initial.held} • '
                    'Sisa ${initial.remainingQuota}. Kuota baru tidak boleh '
                    'kurang dari ${initial.reservedCount}.',
                color: AppTheme.primaryColor,
              ),
            if (initial != null) const SizedBox(height: 16),
            TextFormField(
              key: const Key('ticket-name-field'),
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nama kategori tiket',
                errorText:
                    _fieldErrors[OrganizerEventValidators.fieldTicketName],
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama kategori tiket wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Deskripsi (opsional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('ticket-price-field'),
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Harga (Rp)',
                errorText:
                    _fieldErrors[OrganizerEventValidators.fieldTicketPrice],
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('ticket-quota-field'),
              controller: _quota,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Kuota',
                errorText:
                    _fieldErrors[OrganizerEventValidators.fieldTicketQuota],
              ),
              validator: _validateQuota,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('ticket-max-field'),
              controller: _maxPerOrder,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Batas pembelian per order (opsional)',
                helperText: 'Kosongkan untuk mengikuti batas platform.',
                errorText: _fieldErrors[
                    OrganizerEventValidators.fieldTicketMaxPerOrder],
              ),
            ),
            const SizedBox(height: 8),
            _PeriodTile(
              label: 'Awal periode penjualan',
              value: _salesStart,
              onPick: () => _pickPeriod(isStart: true),
              onClear: () => setState(() => _salesStart = null),
            ),
            _PeriodTile(
              label: 'Akhir periode penjualan',
              value: _salesEnd,
              onPick: () => _pickPeriod(isStart: false),
              onClear: () => setState(() => _salesEnd = null),
            ),
            if (_fieldErrors[OrganizerEventValidators.fieldTicketPeriod] !=
                null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _fieldErrors[OrganizerEventValidators.fieldTicketPeriod]!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kategori aktif'),
              subtitle: const Text(
                'Kategori nonaktif tidak dapat dijual walau kuota tersisa.',
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('ticket-save-button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Simpan perubahan' : 'Tambah kategori'),
            ),

          ],
        ),
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$label: ${value == null ? 'belum diatur' : core.DateUtils.formatDateTime(value)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: label,
              onPressed: onPick,
              icon: const Icon(Icons.event_outlined, size: 20),
            ),
            if (value != null)
              IconButton(
                tooltip: 'Kosongkan',
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      );
}

