/// Team and staff membership management screen (FR-60–65).
///
/// Manages Owner and Staff member listing, invite dispatch, 7-day expiration,
/// acceptance, granular permission checkboxes, and access revocation per PRD.
library;

import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_membership/organizer_membership_service.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../shell/organizer_shell.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({
    super.key,
    this.eventId = 'evt-001',
    this.eventTitle = 'Tech Innovation Summit 2026',
  });

  final String eventId;
  final String eventTitle;

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final OrganizerMembershipService _service = OrganizerMembershipService.instance;
  List<EventMemberModel> _members = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, staff, pending, owner

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final list = await _service.listMembers(widget.eventId);
    if (mounted) {
      setState(() {
        _members = list;
        _isLoading = false;
      });
    }
  }

  void _showInviteStaffDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Default permissions for new staff
    final Set<OrganizerPermission> selectedPermissions = {
      OrganizerPermission.viewEvent,
      OrganizerPermission.scanTicket,
      OrganizerPermission.checkInTicket,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Undang Staf Panitia'),
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
                    'Undangan berlaku selama 7 hari. Calon staf akan menerima akses ke "${widget.eventTitle}" sesuai izin yang dicentang.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Staf *',
                      hintText: 'staf@eventcrew.id',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: InputValidator.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap (Opsional)',
                      hintText: 'Contoh: Ahmad Dhani',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hak Akses & Izin (Granular Permissions PRD):',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...OrganizerPermission.values.map((perm) {
                    final isChecked = selectedPermissions.contains(perm);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(perm.code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(perm.label, style: const TextStyle(fontSize: 11)),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final email = emailController.text.trim();
                  final name = nameController.text.trim();
                  Navigator.pop(ctx);
                  await _service.inviteStaff(
                    eventId: widget.eventId,
                    eventTitle: widget.eventTitle,
                    email: email,
                    name: name,
                    permissions: selectedPermissions,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Undangan staf berhasil dikirim ke $email (Masa aktif 7 hari).'),
                        backgroundColor: Colors.green.shade800,
                      ),
                    );
                    _loadMembers();
                  }
                }
              },
              child: const Text('Kirim Undangan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPermissionsDialog(EventMemberModel member) {
    final Set<OrganizerPermission> tempPermissions = Set.from(member.permissions);

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
                ...OrganizerPermission.values.map((perm) {
                  final isChecked = tempPermissions.contains(perm);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(perm.code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(perm.label, style: const TextStyle(fontSize: 11)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await _service.updatePermissions(
                  eventId: widget.eventId,
                  memberId: member.id,
                  permissions: tempPermissions,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Izin staf ${member.name} berhasil diperbarui.')),
                  );
                  _loadMembers();
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
    final filtered = _members.where((m) {
      if (_filter == 'owner') return m.isOwner;
      if (_filter == 'staff') return m.isStaff && m.isAccepted;
      if (_filter == 'pending') return m.isPending;
      return true;
    }).toList();

    return OrganizerShell(
      currentRoute: AppRoutes.organizerTeam,
      title: 'Manajemen Tim & Staf',
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Undang Staf'),
        onPressed: _showInviteStaffDialog,
      ),
      child: Column(
        children: [
          // Banner context
          Container(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Event Terpilih:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(widget.eventTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Semua (${_members.length})'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Staff Aktif (${_members.where((m) => m.isStaff && m.isAccepted).length})'),
                    selected: _filter == 'staff',
                    onSelected: (_) => setState(() => _filter = 'staff'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Menunggu / Pending (${_members.where((m) => m.isPending).length})'),
                    selected: _filter == 'pending',
                    onSelected: (_) => setState(() => _filter = 'pending'),
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

          const Divider(height: 1),

          // Member List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Belum ada staf anggota pada kategori ini.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: m.isOwner ? Colors.purple.shade50 : Colors.indigo.shade50,
                                        child: Icon(
                                          m.isOwner ? Icons.workspace_premium : Icons.badge,
                                          color: m.isOwner ? Colors.purple : Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            Text(m.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                                            Chip(
                                              label: const Text('Full Access (Owner)', style: TextStyle(fontSize: 11)),
                                              backgroundColor: Colors.purple.shade50,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ]
                                        : m.permissions.map((p) {
                                            return Chip(
                                              label: Text(p.code, style: const TextStyle(fontSize: 10)),
                                              backgroundColor: Colors.blue.shade50,
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
                                          icon: const Icon(Icons.security, size: 16),
                                          label: const Text('Edit Izin'),
                                          onPressed: () => _showEditPermissionsDialog(m),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.person_remove, size: 16, color: Colors.red),
                                          label: const Text('Cabut Akses', style: TextStyle(color: Colors.red)),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text('Cabut Akses Staf?'),
                                                content: Text('Apakah Anda yakin ingin mencabut hak staf dari ${m.name}?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(c, true),
                                                    child: const Text('Cabut'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await _service.revokeAccess(eventId: widget.eventId, memberId: m.id);
                                              _loadMembers();
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

  Widget _buildStatusBadge(EventMemberModel m) {
    if (m.isOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
        child: const Text('Owner', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (m.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
        child: const Text('Pending (7 Hari)', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
      child: const Text('Aktif (Staff)', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
