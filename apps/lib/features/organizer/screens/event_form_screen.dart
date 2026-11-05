import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as core;
import '../../../models/event/event_model.dart';
import '../../../services/organizer_events/organizer_event_contract.dart';
import '../../../services/organizer_events/organizer_event_exceptions.dart';
import '../../../services/organizer_events/organizer_event_fixtures.dart';
import '../../../services/organizer_events/organizer_event_repository.dart';
import '../../../services/organizer_events/organizer_event_validators.dart';
import '../../../services/organizer_events/mock_organizer_event_repository.dart';
import '../../organizer/events/screens/organizer_event_preview_screen.dart';
import '../../organizer/events/widgets/organizer_feedback_view.dart';

/// Form Buat/Edit Event milik Owner (PRD 5.4 A–E).
///
/// Seluruh penyimpanan memakai repository mock lokal (tanpa HTTP). Owner tidak
/// dapat mengubah status moderasi; status hanya berpindah lewat aksi
/// "Ajukan moderasi" yang tersedia untuk draft/revisi.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    this.eventId,
    this.repository,
    this.ownerId,
  });

  /// Null berarti membuat event baru.
  final String? eventId;

  /// Repository bersama; bila null dipakai mock baru (tetap lokal).
  final OrganizerEventRepository? repository;

  final String? ownerId;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _posterUrl = TextEditingController();
  final _organizerName = TextEditingController(
    text: OrganizerEventFixtures.demoOwnerName,
  );
  final _contactInfo = TextEditingController(
    text: OrganizerEventFixtures.demoOwnerEmail,
  );
  final _location = TextEditingController();
  final _onlineUrl = TextEditingController();
  final _publicInfo = TextEditingController();

  late final OrganizerEventRepository _repository;
  late final String _ownerId;

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _timeZone = OrganizerTimeZones.all.first;
  String _format = OrganizerEventFormat.offline;
  String _category = OrganizerEventCategories.all.first;
  final Set<String> _attendeeFields = <String>{OrganizerAttendeeFields.name};

  EventModel? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  Map<String, String> _fieldErrors = const <String, String>{};
  bool _submitAfterSave = false;

  bool get _isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockOrganizerEventRepository.shared();
    _ownerId = widget.ownerId ?? OrganizerEventFixtures.demoOwnerId;
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _posterUrl.dispose();
    _organizerName.dispose();
    _contactInfo.dispose();
    _location.dispose();
    _onlineUrl.dispose();
    _publicInfo.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final event = await _repository.getEvent(
        ownerId: _ownerId,
        eventId: widget.eventId!,
      );
      if (!mounted) return;
      setState(() {
        _existing = event;
        _title.text = event.title;
        _description.text = event.description ?? '';
        _posterUrl.text = event.posterUrl ?? '';
        _organizerName.text = event.organizerName ?? '';
        _contactInfo.text = event.contactInfo ?? '';
        _location.text = event.location ?? '';
        _onlineUrl.text = event.onlineUrl ?? '';
        _publicInfo.text = event.publicInfo ?? '';
        _startDateTime = event.startDateTime;
        _endDateTime = event.endDateTime;
        _timeZone = event.timeZone ?? OrganizerTimeZones.all.first;
        _format = event.eventType;
        _category = event.category ?? OrganizerEventCategories.all.first;
        _attendeeFields
          ..clear()
          ..addAll(
            event.attendeeFields.isEmpty
                ? <String>[OrganizerAttendeeFields.name]
                : event.attendeeFields,
          );
      });
    } on OrganizerEventAccessDeniedException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } on OrganizerEventException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? base.hour,
      time?.minute ?? base.minute,
    );
  }

  OrganizerEventDraft _buildDraft() => OrganizerEventDraft(
        title: _title.text,
        category: _category,
        description: _description.text,
        organizerName: _organizerName.text,
        contactInfo: _contactInfo.text,
        startDateTime: _startDateTime ?? DateTime.now(),
        endDateTime: _endDateTime ?? DateTime.now(),
        timeZone: _timeZone,
        format: _format,
        posterUrl: _posterUrl.text,
        location: _location.text,
        onlineUrl: _onlineUrl.text,
        publicInfo: _publicInfo.text,
        attendeeFields: _attendeeFields.toList(growable: false),
      );

  /// Menyimpan draft; [submitForReview] menentukan aksi setelah simpan.
  Future<void> _save({required bool submitForReview}) async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final draftErrors = OrganizerEventValidators.validateEventDraft(
      _buildDraft(),
    );
    if (!formValid || draftErrors.isNotEmpty) {
      setState(() => _fieldErrors = draftErrors);
      if (_startDateTime == null || _endDateTime == null) {
        _showMessage('Lengkapi tanggal mulai dan tanggal selesai event.');
      } else {
        _showMessage(
          draftErrors.values.isEmpty
              ? 'Periksa kembali isian form.'
              : draftErrors.values.first,
        );
      }
      return;
    }
    setState(() {
      _fieldErrors = const <String, String>{};
      _saving = true;
      _submitAfterSave = submitForReview;
    });

    try {
      final draft = _buildDraft();
      EventModel saved;
      if (_isEditing) {
        saved = await _repository.updateEvent(
          ownerId: _ownerId,
          eventId: widget.eventId!,
          draft: draft,
        );
      } else {
        saved = await _repository.createEvent(ownerId: _ownerId, draft: draft);
      }

      if (submitForReview) {
        saved = await _repository.submitForReview(
          ownerId: _ownerId,
          eventId: saved.id,
        );
      }

      if (!mounted) return;
      _showMessage(
        submitForReview
            ? 'Event "${saved.title}" diajukan. Status: ${saved.statusLabel} '
                '(simulasi).'
            : 'Draft "${saved.title}" tersimpan.',
      );
      Navigator.of(context).pop(true);
    } on OrganizerEventValidationException catch (error) {
      if (!mounted) return;
      setState(() => _fieldErrors = error.fieldErrors);
      _showMessage(error.firstMessage);
    } on OrganizerEventException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _preview() async {
    final draftErrors = OrganizerEventValidators.validateEventDraft(
      _buildDraft(),
    );
    if (draftErrors.isNotEmpty) {
      setState(() => _fieldErrors = draftErrors);
      _showMessage('Lengkapi data sebelum pratinjau: '
          '${draftErrors.values.first}');
      return;
    }
    final existing = _existing;
    final previewEvent = existing != null
        ? existing.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category,
            startDateTime: _startDateTime!,
            endDateTime: _endDateTime!,
            timeZone: _timeZone,
            eventType: _format,
            location: _location.text.trim(),
            onlineUrl: _onlineUrl.text.trim(),
            contactInfo: _contactInfo.text.trim(),
            organizerName: _organizerName.text.trim(),
            publicInfo: _publicInfo.text.trim(),
            attendeeFields: _attendeeFields.toList(growable: false),
          )
        : EventModel(
            id: 'preview',
            organizerId: _ownerId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category,
            startDateTime: _startDateTime!,
            endDateTime: _endDateTime!,
            timeZone: _timeZone,
            location: _location.text.trim(),
            onlineUrl: _onlineUrl.text.trim(),
            eventType: _format,
            contactInfo: _contactInfo.text.trim(),
            organizerName: _organizerName.text.trim(),
            publicInfo: _publicInfo.text.trim(),
            attendeeFields: _attendeeFields.toList(growable: false),
            status: OrganizerEventStatus.draft,
          );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganizerEventPreviewScreen(event: previewEvent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Ubah Event' : 'Buat Event')),
        body: const OrganizerLoadingView(message: 'Memuat data event...'),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Ubah Event' : 'Buat Event')),
        body: OrganizerErrorView(
          message: _loadError!,
          onRetry: _isEditing ? _loadExisting : null,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Event' : 'Buat Event'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Pratinjau halaman publik',
            onPressed: _saving ? null : _preview,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            if (_existing != null)
              OrganizerInfoBanner(
                message: 'Status event saat ini: ${_existing!.statusLabel}. '
                    'Status moderasi hanya berubah melalui aksi pengajuan atau '
                    'keputusan moderator (simulasi).',
              ),
            if (_existing != null) const SizedBox(height: 16),
            _sectionTitle('A. Informasi dasar'),
            TextFormField(
              key: const Key('event-title-field'),
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nama event',
                errorText: _fieldErrors[OrganizerEventValidators.fieldTitle],
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama event wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Kategori event'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _category,
                  items: <DropdownMenuItem<String>>[
                    for (final category in OrganizerEventCategories.all)
                      DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _posterUrl,
              decoration: const InputDecoration(
                labelText: 'URL poster (opsional, fixture demo)',
                helperText: 'Gambar tidak diunduh; hanya disimpan sebagai teks.',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('event-organizer-field'),
              controller: _organizerName,
              decoration: InputDecoration(
                labelText: 'Nama penyelenggara yang ditampilkan',
                errorText:
                    _fieldErrors[OrganizerEventValidators.fieldOrganizerName],
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama penyelenggara wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('event-contact-field'),
              controller: _contactInfo,
              decoration: InputDecoration(
                labelText: 'Kontak penyelenggara (email/telepon)',
                errorText:
                    _fieldErrors[OrganizerEventValidators.fieldContactInfo],
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Kontak penyelenggara wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 24),
            _sectionTitle('B. Jadwal'),
            _dateTile(
              key: const Key('event-start-tile'),
              label: 'Mulai',
              value: _startDateTime,
              onPick: () async {
                final picked = await _pickDateTime(_startDateTime);
                if (picked != null) setState(() => _startDateTime = picked);
              },
            ),
            _dateTile(
              key: const Key('event-end-tile'),
              label: 'Selesai',
              value: _endDateTime,
              onPick: () async {
                final picked = await _pickDateTime(_endDateTime);
                if (picked != null) setState(() => _endDateTime = picked);
              },
            ),
            if (_fieldErrors[OrganizerEventValidators.fieldEnd] != null)
              _errorText(_fieldErrors[OrganizerEventValidators.fieldEnd]!),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Zona waktu'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _timeZone,
                  items: <DropdownMenuItem<String>>[
                    for (final zone in OrganizerTimeZones.all)
                      DropdownMenuItem<String>(
                        value: zone,
                        child: Text(OrganizerTimeZones.label(zone)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _timeZone = value ?? _timeZone),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('C. Lokasi dan format'),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Format event'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _format,
                  items: <DropdownMenuItem<String>>[
                    for (final format in OrganizerEventFormat.all)
                      DropdownMenuItem<String>(
                        value: format,
                        child: Text(OrganizerEventFormat.label(format)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _format = value ?? _format),
                ),
              ),
            ),
            if (_format != OrganizerEventFormat.online) ...<Widget>[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('event-location-field'),
                controller: _location,
                decoration: InputDecoration(
                  labelText: 'Alamat lokasi',
                  errorText:
                      _fieldErrors[OrganizerEventValidators.fieldLocation],
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Alamat lokasi wajib diisi untuk event offline/hybrid.'
                    : null,
              ),
            ],
            if (_format != OrganizerEventFormat.offline) ...<Widget>[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('event-online-field'),
                controller: _onlineUrl,
                decoration: InputDecoration(
                  labelText: 'Tautan online',
                  hintText: 'https://',
                  errorText:
                      _fieldErrors[OrganizerEventValidators.fieldOnlineUrl],
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Tautan online wajib untuk event online/hybrid.';
                  }
                  if (!text.startsWith('http://') &&
                      !text.startsWith('https://')) {
                    return 'Tautan harus diawali http:// atau https://.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            _sectionTitle('D. Kategori tiket'),
            const Text(
              'Kategori tiket dikelola pada detail event setelah draft tersimpan '
              'agar aturan kuota dan riwayat transaksi dapat dijaga.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _sectionTitle('E. Pengaturan registrasi'),
            const Text(
              'Data peserta yang wajib diisi',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: true,
              onChanged: null,
              title: const Text('Nama lengkap'),
              subtitle: const Text('Selalu wajib dan tidak dapat dilepas.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            for (final field in OrganizerAttendeeFields.optional)
              CheckboxListTile(
                key: Key('attendee-field-$field'),
                contentPadding: EdgeInsets.zero,
                value: _attendeeFields.contains(field),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _attendeeFields.add(field);
                  } else {
                    _attendeeFields.remove(field);
                  }
                }),
                title: Text(OrganizerAttendeeFields.label(field)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (_fieldErrors[OrganizerEventValidators.fieldAttendeeFields] !=
                null)
              _errorText(
                _fieldErrors[OrganizerEventValidators.fieldAttendeeFields]!,
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _publicInfo,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Informasi yang tampil di halaman publik',
              ),
            ),
            const SizedBox(height: 12),
            const OrganizerInfoBanner(
              message: 'Batas waktu pembayaran mengikuti kebijakan platform '
                  'yang belum ditetapkan, sehingga tidak dapat diatur di sini.',
              icon: Icons.schedule,
            ),


          ],
        ),
      ),
      bottomNavigationBar: _buildActions(),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );

  Widget _errorText(String message) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
        ),
      );

  Widget _dateTile({
    required Key key,
    required String label,
    required DateTime? value,
    required Future<void> Function() onPick,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '$label: ${value == null ? 'belum diatur' : core.DateUtils.formatDateTime(value)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            OutlinedButton(
              key: key,
              onPressed: onPick,
              child: Text(value == null ? 'Pilih' : 'Ubah'),
            ),
          ],
        ),
      );

  Widget _buildActions() {
    final canSubmit = _existing == null || _existing!.canSubmitForReview;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                key: const Key('event-save-draft-button'),
                onPressed: _saving ? null : () => _save(submitForReview: false),
                child: _saving && !_submitAfterSave
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('event-submit-button'),
                onPressed: (_saving || !canSubmit)
                    ? null
                    : () => _save(submitForReview: true),
                child: _saving && _submitAfterSave
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan & ajukan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
