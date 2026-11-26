/// Builder field pendaftaran bertipe untuk form event Organizer (T3-D1-04).
///
/// Mendukung tipe `text|textarea|number|date|select|checkbox`, penanda wajib,
/// opsi untuk `select`, serta tambah/ubah/hapus/urutkan field. Validasi kunci
/// unik dan tidak kosong dilakukan di sini dan diulang server.
library;

import 'package:flutter/material.dart';

import '../../../../models/event/attendee_field_definition.dart';

class AttendeeFieldBuilder extends StatefulWidget {
  const AttendeeFieldBuilder({
    super.key,
    required this.fields,
    required this.onChanged,
    this.errorText,
  });

  /// Daftar field saat ini. Widget memegang salinan sendiri lalu melaporkan
  /// setiap perubahan lewat [onChanged].
  final List<AttendeeFieldDefinition> fields;
  final ValueChanged<List<AttendeeFieldDefinition>> onChanged;
  final String? errorText;

  /// Kolom wajib pada tabel `attendees`; tidak boleh dihapus.
  static const Set<String> lockedKeys = <String>{'name', 'email'};

  @override
  State<AttendeeFieldBuilder> createState() => _AttendeeFieldBuilderState();
}

class _AttendeeFieldBuilderState extends State<AttendeeFieldBuilder> {
  late List<AttendeeFieldDefinition> _fields;
  String? _localError;

  static const Map<String, String> typeLabels = <String, String>{
    AttendeeFieldDefinition.typeText: 'Teks singkat',
    AttendeeFieldDefinition.typeTextarea: 'Teks panjang',
    AttendeeFieldDefinition.typeNumber: 'Angka',
    AttendeeFieldDefinition.typeDate: 'Tanggal',
    AttendeeFieldDefinition.typeSelect: 'Pilihan (dropdown)',
    AttendeeFieldDefinition.typeCheckbox: 'Centang (checkbox)',
  };

  @override
  void initState() {
    super.initState();
    _fields = List<AttendeeFieldDefinition>.from(widget.fields);
  }

  @override
  void didUpdateWidget(AttendeeFieldBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.fields, widget.fields) &&
        widget.fields.length != _fields.length) {
      _fields = List<AttendeeFieldDefinition>.from(widget.fields);
    }
  }

  void _emit() {
    setState(() => _localError = null);
    widget.onChanged(List<AttendeeFieldDefinition>.unmodifiable(_fields));
  }

  Future<void> _editField({AttendeeFieldDefinition? existing}) async {
    final result = await showDialog<AttendeeFieldDefinition>(
      context: context,
      builder: (_) => AttendeeFieldDialog(
        existing: existing,
        takenKeys: _fields
            .where((field) => field.key != existing?.key)
            .map((field) => field.key)
            .toSet(),
      ),
    );
    if (result == null) return;
    final index = existing == null
        ? -1
        : _fields.indexWhere((field) => field.key == existing.key);
    if (index >= 0) {
      _fields[index] = result;
    } else {
      _fields.add(result);
    }
    _emit();
  }

  void _removeField(AttendeeFieldDefinition field) {
    if (AttendeeFieldBuilder.lockedKeys.contains(field.key)) {
      setState(
        () => _localError =
            'Field "${field.label}" wajib ada dan tidak dapat dihapus.',
      );
      return;
    }
    _fields.removeWhere((item) => item.key == field.key);
    _emit();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _fields.length) return;
    final item = _fields.removeAt(index);
    _fields.insert(target, item);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText ?? _localError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pertanyaan Pendaftaran Peserta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            TextButton.icon(
              onPressed: () => _editField(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah field'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Nama dan Email selalu wajib. Field lain dapat diberi tipe, '
          'ditandai wajib, dan diurutkan.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (_fields.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada field pendaftaran.'),
          ),
        for (var i = 0; i < _fields.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(
                '${_fields[i].label}${_fields[i].required ? ' *' : ''}',
              ),
              subtitle: Text(
                '${_AttendeeFieldBuilderState.typeLabels[_fields[i].type] ?? _fields[i].type}'
                '${_fields[i].isSelect ? ' · ${_fields[i].options.join(', ')}' : ''}'
                '\nkey: ${_fields[i].key}',
              ),
              isThreeLine: _fields[i].isSelect,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Naikkan',
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: i == 0 ? null : () => _move(i, -1),
                  ),
                  IconButton(
                    tooltip: 'Turunkan',
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed:
                        i == _fields.length - 1 ? null : () => _move(i, 1),
                  ),
                  IconButton(
                    tooltip: 'Ubah',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _editField(existing: _fields[i]),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed:
                        AttendeeFieldBuilder.lockedKeys.contains(_fields[i].key)
                            ? null
                            : () => _removeField(_fields[i]),
                  ),
                ],
              ),
              onTap: () => _editField(existing: _fields[i]),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Dialog tambah/ubah satu field pendaftaran.
class AttendeeFieldDialog extends StatefulWidget {
  const AttendeeFieldDialog({
    super.key,
    this.existing,
    required this.takenKeys,
  });

  final AttendeeFieldDefinition? existing;
  final Set<String> takenKeys;

  @override
  State<AttendeeFieldDialog> createState() => _AttendeeFieldDialogState();
}

class _AttendeeFieldDialogState extends State<AttendeeFieldDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late final TextEditingController _optionsController;
  late String _type;
  late bool _required;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _keyController = TextEditingController(text: existing?.key ?? '');
    _labelController = TextEditingController(text: existing?.label ?? '');
    _optionsController =
        TextEditingController(text: existing?.options.join(', ') ?? '');
    _type = existing?.type ?? AttendeeFieldDefinition.typeText;
    _required = existing?.required ?? false;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _keyController.text.trim().toLowerCase();
    final label = _labelController.text.trim();
    if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(key)) {
      setState(
        () => _error =
            'Kunci field harus huruf kecil/angka/underscore dan diawali huruf.',
      );
      return;
    }
    if (widget.takenKeys.contains(key)) {
      setState(() => _error = 'Kunci field "$key" sudah dipakai.');
      return;
    }
    if (label.isEmpty) {
      setState(() => _error = 'Label field tidak boleh kosong.');
      return;
    }
    final options = _optionsController.text
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    if (_type == AttendeeFieldDefinition.typeSelect && options.length < 2) {
      setState(() => _error = 'Field pilihan memerlukan minimal 2 opsi.');
      return;
    }
    Navigator.pop(
      context,
      AttendeeFieldDefinition(
        key: key,
        label: label,
        type: _type,
        required: _required,
        options: _type == AttendeeFieldDefinition.typeSelect
            ? options
            : const <String>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah Field' : 'Ubah Field'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label pertanyaan',
                hintText: 'Contoh: Ukuran Kaos',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              enabled: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Kunci field',
                hintText: 'ukuran_kaos',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipe field'),
              items: _AttendeeFieldBuilderState.typeLabels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            if (_type == AttendeeFieldDefinition.typeSelect) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _optionsController,
                decoration: const InputDecoration(
                  labelText: 'Opsi (pisahkan dengan koma)',
                  hintText: 'S, M, L',
                ),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wajib diisi'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
