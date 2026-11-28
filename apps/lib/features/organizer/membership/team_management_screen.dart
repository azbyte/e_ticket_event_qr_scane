/// Team and staff membership management screen (FR-60–65).
///
/// Manages Owner and Staff member listing, invite dispatch, 7-day expiration,
/// acceptance, granular permission checkboxes, and access revocation per PRD.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_membership/organizer_membership_service.dart';
import '../../../services/organizer_membership/staff_invitation_service.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../shell/organizer_shell.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({
    super.key,
    this.eventId = '',
    this.eventTitle = 'Event',
    this.membershipService,
    this.invitationService,
  });

  final String eventId;
  final String eventTitle;

  /// Dapat diinjeksi untuk pengujian; default memakai service produksi.
  final OrganizerMembershipService? membershipService;
  final StaffInvitationService? invitationService;

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  late final OrganizerMembershipService _service =
      widget.membershipService ?? OrganizerMembershipService.instance;
  late final StaffInvitationService _invitationService =
      widget.invitationService ?? StaffInvitationService();
  List<EventMemberModel> _members = [];
  List<StaffInvitation> _invitations = [];
  bool _isLoading = true;
  String? _loadError;

  /// Kesalahan khusus daftar staf/kode akses. Dipisahkan dari [_loadError]
  /// agar anggota lama tetap tampil, tetapi kegagalan fitur staf tidak
  /// disembunyikan (Organizer harus tahu kenapa kode akses tidak muncul).
  String? _invitationError;
  String _filter = 'all'; // all, invitations, staff, owner

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  /// Muat anggota aktif dan undangan staf (nama + kode akses) sekaligus.
  Future<void> _loadMembers() async {
    if (widget.eventId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _loadError =
            'Event belum dipilih. Buka halaman ini dari detail event agar '
            'staf dapat ditambahkan.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
      _invitationError = null;
    });
    try {
      final members = await _service.listMembers(
        widget.eventId,
        eventTitle: widget.eventTitle,
      );
      List<StaffInvitation> invitations = const <StaffInvitation>[];
      String? invitationError;
      try {
        invitations = await _invitationService.list(widget.eventId);
      } on Exception catch (error) {
        // Anggota lama tetap ditampilkan, tetapi kegagalan daftar staf
        // dilaporkan pada banner terpisah supaya tidak tampak seperti
        // "belum ada staf" padahal server gagal memuat.
        invitations = const <StaffInvitation>[];
        invitationError = _describeStaffError(error);
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _invitationError = invitationError;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteStaffDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // Status pengiriman disimpan di closure agar dialog tidak langsung tertutup
    // saat gagal; Organizer dapat membaca penyebabnya dan mencoba lagi tanpa
    // mengetik ulang nama staf.
    bool isSubmitting = false;
    String? submitError;

    // Default permissions for new staff
    final Set<OrganizerPermission> selectedPermissions = {
      OrganizerPermission.viewEvent,
      OrganizerPermission.scanTicket,
      OrganizerPermission.checkInTicket,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFFC94426)),
              SizedBox(width: 8),
              Expanded(child: Text('Tambahkan Staf')),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masukkan nama staf. Sistem akan membuat kode akses unik dan '
                    'tautan undangan untuk event "${widget.eventTitle}". Staf '
                    'tidak perlu memiliki akun.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('staff-invitation-name'),
                    controller: nameController,
                    autofocus: true,
                    enabled: !isSubmitting,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Staf *',
                      hintText: 'Contoh: Ahmad Dhani',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (value) {
                      final name = (value ?? '').trim();
                      if (name.length < 2) {
                        return 'Nama staf minimal 2 karakter.';
                      }
                      if (name.length > 80) {
                        return 'Nama staf maksimal 80 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hak Akses & Izin (Granular Permissions PRD):',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...OrganizerPermission.values
                      .where((p) => p != OrganizerPermission.assistRegistration)
                      .map((perm) {
                        final isChecked = selectedPermissions.contains(perm);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            perm.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            perm.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedPermissions.add(perm);
                              } else {
                                selectedPermissions.remove(perm);
                              }
                            });
                          },
                        );
                      }),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('staff-invitation-submit-error'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        submitError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('staff-invitation-submit'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final name = nameController.text.trim();
                      setDialogState(() {
                        isSubmitting = true;
                        submitError = null;
                      });
                      try {
                        final invitation = await _invitationService.create(
                          eventId: widget.eventId,
                          name: name,
                          permissions: selectedPermissions.map((p) => p.code),
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadMembers();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Staf $name berhasil ditambahkan.',
                            ),
                            backgroundColor: Colors.green.shade800,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        await _showInvitationResult(invitation);
                      } on Exception catch (error) {
                        if (!mounted || !ctx.mounted) return;
                        setDialogState(() {
                          isSubmitting = false;
                          submitError = _describeStaffError(error);
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tambahkan Staf'),
            ),
          ],
        ),
      ),
    );
    // Catatan: `nameController` tidak di-dispose di sini karena route dialog
    // masih beranimasi keluar dan TextFormField-nya masih memakai controller.
  }

  Future<void> _copyValue(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Tampilkan kode akses + tautan undangan yang baru dibuat/diperbarui.
  ///
  /// Kode akses hanya dapat dilihat pada halaman ini (endpoint dilindungi
  /// kepemilikan event). Staf tetap harus memasukkan kode pada tautan; tautan
  /// sendiri tidak memberi akses scanner.
  Future<void> _showInvitationResult(StaffInvitation invitation) async {
    final code = invitation.accessCode ?? '-';
    final link = invitation.inviteUrl ?? '-';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('staff-invitation-result-dialog'),
        title: const Row(
          children: <Widget>[
            Icon(Icons.mark_email_read_outlined, color: Color(0xFFC94426)),
            SizedBox(width: 8),
            Expanded(child: Text('Staf Ditambahkan')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Staf ${invitation.staffName} berhasil ditambahkan. Bagikan '
                'kode akses dan tautan berikut kepada staf tersebut.',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _InvitationValueRow(
                label: 'Nama staf',
                value: invitation.staffName,
                valueKey: const Key('staff-invitation-result-name'),
              ),
              const SizedBox(height: 10),
              _InvitationValueRow(
                label: 'Kode akses',
                value: code,
                valueKey: const Key('staff-invitation-result-code'),
                emphasize: true,
                onCopy: invitation.accessCode == null
                    ? null
                    : () => _copyValue(code, 'Kode akses'),
              ),
              const SizedBox(height: 10),
              _InvitationValueRow(
                label: 'Tautan undangan',
                value: link,
                valueKey: const Key('staff-invitation-result-link'),
                onCopy: invitation.inviteUrl == null
                    ? null
                    : () => _copyValue(link, 'Tautan undangan'),
              ),
              if (invitation.expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Berlaku sampai ${_formatDate(invitation.expiresAt!)}. '
                    'Staf memasukkan kode akses pada tautan untuk membuka '
                    'scanner event ini.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (invitation.accessCode != null && invitation.inviteUrl != null)
            FilledButton.icon(
              key: const Key('staff-invitation-copy-both'),
              onPressed: () => _copyValue(
                'Nama: ${invitation.staffName}\n'
                    'Kode akses: ${invitation.accessCode}\n'
                    'Tautan: ${invitation.inviteUrl}',
                'Detail undangan',
              ),
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Salin Semua'),
            ),
        ],
      ),
    );
  }

  Future<void> _regenerateInvitation(StaffInvitation invitation) async {
    final nameController = TextEditingController(
      text: invitation.staffName == 'Staf' ? '' : invitation.staffName,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Buat Kode Akses Baru?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Kode akses lama akan langsung tidak berlaku dan undangan '
              'berlaku kembali selama 7 hari.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('staff-invitation-regenerate-name'),
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama staf',
                helperText: 'Dapat diperbarui untuk undangan lama',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('staff-invitation-regenerate-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Buat Kode Baru'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = nameController.text.trim();
    // `nameController` tidak di-dispose di sini: route dialog masih beranimasi
    // keluar dan TextField-nya masih memakai controller tersebut.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await _invitationService.regenerate(
        eventId: widget.eventId,
        invitationId: invitation.id,
        name: name,
      );
      if (!mounted) return;
      await _loadMembers();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kode akses baru dibuat. Kode lama tidak berlaku.'),
        ),
      );
      await _showInvitationResult(updated);
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Kode akses gagal diperbarui: $error')),
        );
      }
    }
  }

  Future<void> _revokeInvitation(StaffInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cabut Akses Staf?'),
        content: Text(
          'Akses ${invitation.staffName} ke scanner event ini akan langsung '
          'dicabut dan kode aksesnya tidak dapat dipakai lagi.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _invitationService.revoke(
        eventId: widget.eventId,
        invitationId: invitation.id,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Akses staf ${invitation.staffName} dicabut.')),
      );
      await _loadMembers();
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Akses staf gagal dicabut: $error')),
        );
      }
    }
  }

  /// Pesan kegagalan yang layak dibaca Organizer (tanpa prefix kelas exception).
  static String _describeStaffError(Object error) {
    if (error is AppException) {
      final message = error.message.trim();
      return message.isEmpty ? 'Staf gagal ditambahkan. Coba lagi.' : message;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  void _showEditPermissionsDialog(EventMemberModel member) {
    final Set<OrganizerPermission> tempPermissions = Set.from(
      member.permissions,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Izin • ${member.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur hak akses staf pada event "${widget.eventTitle}":',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...OrganizerPermission.values
                    .where((p) => p != OrganizerPermission.assistRegistration)
                    .map((perm) {
                      final isChecked = tempPermissions.contains(perm);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          perm.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          perm.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempPermissions.add(perm);
                            } else {
                              tempPermissions.remove(perm);
                            }
                          });
                        },
                      );
                    }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final updated = await _service.updatePermissions(
                    eventId: widget.eventId,
                    memberId: member.id,
                    permissions: tempPermissions,
                    userId: member.userId,
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        updated
                            ? 'Izin staf ${member.name} diperbarui.'
                            : 'Izin staf tidak dapat diperbarui.',
                      ),
                    ),
                  );
                  if (updated) await _loadMembers();
                } on Exception catch (error) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Izin gagal diperbarui: $error')),
                    );
                  }
                }
              },
              child: const Text('Simpan Izin'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Undangan staf (nama + kode akses) adalah daftar utama; anggota aktif
    // (Owner/staff lama) tetap ditampilkan agar data lama tidak hilang.
    final showInvitations = _filter == 'all' || _filter == 'invitations';
    final invitations = showInvitations
        ? _invitations
        : const <StaffInvitation>[];
    final filteredMembers = _members.where((m) {
      if (_filter == 'owner') return m.isOwner;
      if (_filter == 'staff') return m.isStaff && m.isAccepted;
      return _filter == 'all';
    }).toList();
    final isEmpty = invitations.isEmpty && filteredMembers.isEmpty;
    final activeInvitations = _invitations.where((i) => i.isActive).length;

    return OrganizerShell(
      currentRoute: AppRoutes.organizerTeam,
      title: 'Manajemen Tim & Staf',
      floatingActionButton: widget.eventId.trim().isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('staff-add-fab'),
              icon: const Icon(Icons.person_add),
              label: const Text('Tambahkan Staf'),
              onPressed: _showInviteStaffDialog,
            ),
      child: Column(
        children: [
          // Banner context
          Container(
            color: const Color(0xFFEAEAEA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.event, color: Color(0xFFC94426)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Event Terpilih:',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        widget.eventTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Segarkan',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMembers,
                ),
              ],
            ),
          ),

          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      'Semua (${_invitations.length + _members.length})',
                    ),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('team-filter-invitations'),
                    label: Text('Staf Ditambahkan (${_invitations.length})'),
                    selected: _filter == 'invitations',
                    onSelected: (_) => setState(() => _filter = 'invitations'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Staf Aktif (${_members.where((m) => m.isStaff && m.isAccepted).length})',
                    ),
                    selected: _filter == 'staff',
                    onSelected: (_) => setState(() => _filter = 'staff'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Owner Event'),
                    selected: _filter == 'owner',
                    onSelected: (_) => setState(() => _filter = 'owner'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.key_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$activeInvitations staf aktif · staf masuk dengan kode '
                    'akses pada tautan undangan.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (_invitationError != null)
            Container(
              key: const Key('staff-invitation-load-error'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daftar staf gagal dimuat: $_invitationError',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMembers,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Member List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadMembers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada staf yang ditambahkan pada event ini.',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gunakan tombol "Tambahkan Staf" untuk membuat nama, '
                          'kode akses, dan tautan undangan staf.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: invitations.length + filteredMembers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index < invitations.length) {
                        return _buildInvitationCard(invitations[index]);
                      }
                      final m = filteredMembers[index - invitations.length];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: m.isOwner
                                        ? const Color(0xFFFDF3F1)
                                        : const Color(0xFFEAEAEA),
                                    child: Icon(
                                      m.isOwner
                                          ? Icons.workspace_premium
                                          : Icons.badge,
                                      color: m.isOwner
                                          ? const Color(0xFFC94426)
                                          : const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          m.email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(m),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: m.isOwner
                                    ? [
                                        const Chip(
                                          label: Text(
                                            'Full Access (Owner)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFC94426),
                                            ),
                                          ),
                                          backgroundColor: Color(0xFFFDF3F1),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ]
                                    : m.permissions.map((p) {
                                        return Chip(
                                          label: Text(
                                            p.code,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF181818),
                                            ),
                                          ),
                                          backgroundColor: const Color(
                                            0xFFEAEAEA,
                                          ),
                                          padding: EdgeInsets.zero,
                                        );
                                      }).toList(),
                              ),
                              if (!m.isOwner) ...[
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.security,
                                        size: 16,
                                      ),
                                      label: const Text('Edit Izin'),
                                      onPressed: () =>
                                          _showEditPermissionsDialog(m),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.person_remove,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Cabut Akses',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text(
                                              'Cabut Akses Staf?',
                                            ),
                                            content: Text(
                                              'Apakah Anda yakin ingin mencabut hak staf dari ${m.name}?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('Batal'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Cabut'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            final revoked = await _service
                                                .revokeAccess(
                                                  eventId: widget.eventId,
                                                  memberId: m.id,
                                                  userId: m.userId,
                                                );
                                            if (!mounted) return;
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  revoked
                                                      ? 'Akses ${m.name} dicabut.'
                                                      : 'Akses staf tidak dapat dicabut.',
                                                ),
                                              ),
                                            );
                                            if (revoked) {
                                              await _loadMembers();
                                            }
                                          } on Exception catch (error) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Akses gagal dicabut: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Kartu undangan staf: nama, kode akses, tautan, status, dan aksi kelola.
  Widget _buildInvitationCard(StaffInvitation invitation) {
    final code = invitation.accessCode;
    final link = invitation.inviteUrl;
    return Card(
      key: Key('staff-invitation-${invitation.id}'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: Color(0xFFFDF3F1),
                  child: Icon(
                    Icons.person_pin_circle,
                    color: Color(0xFFC94426),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        invitation.staffName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        invitation.isActive
                            ? 'Staf panitia · akses scanner'
                            : 'Akses staf tidak aktif',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildInvitationStatusBadge(invitation),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E2E2)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.key, size: 16, color: Color(0xFFC94426)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      code ?? 'Kode tidak tersedia — buat kode baru',
                      key: Key('staff-invitation-code-${invitation.id}'),
                      style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: code == null ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  if (code != null)
                    IconButton(
                      key: Key('staff-invitation-copy-code-${invitation.id}'),
                      tooltip: 'Salin kode akses',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyValue(code, 'Kode akses'),
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                ],
              ),
            ),
            if (link != null) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.link, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link,
                      key: Key('staff-invitation-link-${invitation.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('staff-invitation-copy-link-${invitation.id}'),
                    tooltip: 'Salin tautan undangan',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyValue(link, 'Tautan undangan'),
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            ],
            if (invitation.permissions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: invitation.permissions
                      .map(
                        (permission) => Chip(
                          label: Text(
                            permission,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF181818),
                            ),
                          ),
                          backgroundColor: const Color(0xFFEAEAEA),
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  key: Key('staff-invitation-regenerate-${invitation.id}'),
                  icon: const Icon(Icons.autorenew, size: 16),
                  label: const Text('Buat Kode Baru'),
                  onPressed: () => _regenerateInvitation(invitation),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: Key('staff-invitation-revoke-${invitation.id}'),
                  icon: const Icon(
                    Icons.person_remove,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Cabut Akses',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: invitation.isRevoked
                      ? null
                      : () => _revokeInvitation(invitation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationStatusBadge(StaffInvitation invitation) {
    final String label;
    final Color color;
    final Color background;
    switch (invitation.status) {
      case 'ACCEPTED':
        label = 'Aktif';
        color = Colors.green;
        background = Colors.green.shade50;
        break;
      case 'REVOKED':
        label = 'Dicabut';
        color = Colors.red;
        background = Colors.red.shade50;
        break;
      case 'EXPIRED':
        label = 'Kedaluwarsa';
        color = Colors.orange;
        background = Colors.orange.shade50;
        break;
      default:
        label = 'Menunggu';
        color = Colors.orange;
        background = Colors.orange.shade50;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EventMemberModel m) {
    if (m.isOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3F1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Owner',
          style: TextStyle(
            color: Color(0xFFC94426),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (m.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Pending (7 Hari)',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Aktif (Staff)',
        style: TextStyle(
          color: Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Baris nilai undangan (nama/kode/tautan) dengan tombol salin.
class _InvitationValueRow extends StatelessWidget {
  const _InvitationValueRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasize = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasize;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      const SizedBox(height: 2),
      Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              value,
              key: valueKey,
              style: TextStyle(
                fontSize: emphasize ? 18 : 12.5,
                letterSpacing: emphasize ? 2 : 0,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? const Color(0xFFC94426) : Colors.black87,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Salin $label',
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
            ),
        ],
      ),
    ],
  );
}
