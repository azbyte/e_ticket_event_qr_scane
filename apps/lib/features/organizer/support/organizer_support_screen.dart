/// Organizer help center and complaint ticket tracking screen (FR-95, FR-96).
///
/// Features FAQ guidance, trouble ticket submission, secure ticket number tracking,
/// and public resolution replies (admin internal notes strictly hidden).
library;

import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_support/organizer_support_service.dart';
import '../shell/organizer_shell.dart';

class OrganizerSupportScreen extends StatefulWidget {
  const OrganizerSupportScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<OrganizerSupportScreen> createState() => _OrganizerSupportScreenState();
}

class _OrganizerSupportScreenState extends State<OrganizerSupportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final OrganizerSupportService _service = OrganizerSupportService.instance;

  List<OrganizerComplaintModel> _complaints = [];
  bool _isLoading = true;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'organizer@techsummit.id');
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Moderasi Event';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    final list = await _service.listComplaints('org-001');
    if (mounted) {
      setState(() {
        _complaints = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    final created = await _service.submitComplaint(
      organizerId: 'org-001',
      email: _emailController.text.trim(),
      category: _selectedCategory,
      subject: _subjectController.text.trim(),
      description: _descController.text.trim(),
    );

    if (mounted) {
      _subjectController.clear();
      _descController.clear();
      _tabController.animateTo(1); // Jump to complaints list tab
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan ${created.ticketNumber} berhasil dikirim ke tim admin platform.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      _loadComplaints();
    }
  }

  void _showDetailDialog(OrganizerComplaintModel complaint) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text(complaint.ticketNumber, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subjek: ${complaint.subject}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Kategori: ${complaint.category} • Status: ${complaint.status.toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 20),
              const Text('Riwayat Komunikasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (complaint.replies.isEmpty)
                const Text('Belum ada tanggapan.', style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ...complaint.replies.map((r) {
                  final isAdmin = r.sender.toLowerCase().contains('admin');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isAdmin ? Colors.blue.shade200 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.sender,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isAdmin ? Colors.blue.shade900 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(r.message, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              // Note per FR-96: internal notes are completely excluded from presentation
              const Text(
                'Catatan: Tiket dipantau oleh Helpdesk Platform E-Ticket.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerSupport,
      title: 'Pusat Bantuan & Laporan',
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.help_center_outlined), text: 'FAQ & Bantuan'),
              Tab(icon: Icon(Icons.support_agent_outlined), text: 'Laporan Saya'),
              Tab(icon: Icon(Icons.add_comment_outlined), text: 'Buat Laporan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFaqTab(),
                _buildComplaintsTab(),
                _buildCreateComplaintTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final faqs = _service.getFaqs();
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.headset_mic_outlined, color: Colors.indigo, size: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kontak Dukungan Resmi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('Email: support@eticketplatform.id\nWhatsApp: +62 812-3456-7890 (Hari Kerja 09:00 - 17:00)',
                          style: TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Pertanyaan yang Sering Diajukan (FAQ):',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...faqs.map(
          (faq) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(faq.category, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(faq.answer, style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Belum ada tiket keluhan yang diajukan.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _complaints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = _complaints[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(c.status).withValues(alpha: 0.15),
              child: Icon(Icons.report_problem_outlined, color: _getStatusColor(c.status)),
            ),
            title: Text(c.ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${c.subject}\nKategori: ${c.category} • ${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}'),
            isThreeLine: true,
            trailing: _buildStatusBadge(c.status),
            onTap: () => _showDetailDialog(c),
          ),
        );
      },
    );
  }

  Widget _buildCreateComplaintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Formulir Pengaduan & Bantuan Penyelenggara',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sampaikan kendala teknis, status moderasi event, atau pertanyaan langganan kepada tim admin platform.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Kontak Organizer *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: InputValidator.email,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori Masalah *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'Moderasi Event', child: Text('Moderasi & Verifikasi Event')),
                DropdownMenuItem(value: 'Undangan Staf', child: Text('Undangan & Hak Akses Staf')),
                DropdownMenuItem(value: 'Scanner & Check-in', child: Text('Kendala Pemindai / QR Check-in')),
                DropdownMenuItem(value: 'Paket & Langganan', child: Text('Paket & Tagihan Langganan')),
                DropdownMenuItem(value: 'Lainnya', child: Text('Pertanyaan Umum / Lainnya')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subjek Keluhan *',
                hintText: 'Cth: Kendala aktivasi staf di pintu masuk',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: InputValidator.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Rincian Penjelasan *',
                hintText: 'Jelaskan kronologi kendala selengkap mungkin...',
                border: OutlineInputBorder(),
              ),
              validator: InputValidator.required,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Kirim Tiket Laporan'),
              onPressed: _submitComplaint,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
