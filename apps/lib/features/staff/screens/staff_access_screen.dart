/// Halaman autentikasi staf dari tautan undangan (`/staff-access/:invitationId`).
///
/// Tautan undangan hanya mengidentifikasi undangan. Halaman ini SELALU meminta
/// kode akses; pengunjung tidak pernah diarahkan langsung ke scanner. Kode
/// divalidasi backend (`POST /api/staff-access/validate`) yang juga memeriksa
/// status undangan, masa berlaku, dan event undangan. Bila kode salah/undangan
/// tidak aktif, halaman menampilkan penolakan dan tidak membuka scanner.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/staff_access/staff_access_service.dart';

class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({
    super.key,
    required this.invitationId,
    this.service,
  });

  /// Id undangan dari tautan (`/staff-access/{invitationId}`).
  final String invitationId;

  /// Dapat diganti pada test agar tidak memanggil HTTP.
  final StaffAccessService? service;

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  late final StaffAccessService _service =
      widget.service ?? StaffAccessService();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loadingPreview = true;
  StaffInvitationPreview? _preview;
  String? _previewError;
  bool _submitting = false;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    try {
      final preview = await _service.previewInvitation(widget.invitationId);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } on StaffAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _previewError = error.message;
        _loadingPreview = false;
      });
    }
  }

  /// Kode akses: 8 karakter alfanumerik (tanda hubung opsional).
  static String _normalizeCode(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _accessError = null;
    });
    try {
      final session = await _service.requestAccess(
        invitationId: widget.invitationId,
        accessCode: _codeController.text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      // Baru setelah backend menerima kode, staf diarahkan ke scanner event
      // undangannya (bukan event lain).
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.staffScannerAccess,
        arguments: <String, dynamic>{
          'eventId': session.eventId,
          'eventTitle': session.eventTitle,
        },
      );
    } on StaffAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _accessError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akses Staf Event')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingPreview) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_previewError != null) {
      return _DeniedCard(
        key: const Key('staff-access-denied'),
        title: 'Undangan tidak dapat dibuka',
        message: _previewError!,
        onRetry: _loadPreview,
      );
    }

    final preview = _preview!;
    final blocked =
        preview.isRevoked || preview.isExpired || preview.requiresNewCode;
    return Card(
      key: const Key('staff-access-card'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: AppTheme.softTerracottaBg,
                  child: Icon(
                    Icons.badge_outlined,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Undangan staf',
                        style: TextStyle(fontSize: 11.5, color: Colors.black45),
                      ),
                      Text(
                        preview.eventTitle,
                        key: const Key('staff-access-event-title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Halo ${preview.staffName}, masukkan kode akses yang diberikan '
              'Organizer untuk membuka scanner event ini.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            if (preview.eventDate != null ||
                (preview.location ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  <String>[
                    if (preview.eventDate != null)
                      _formatDate(preview.eventDate!),
                    if ((preview.location ?? '').isNotEmpty) preview.location!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ),
            const SizedBox(height: 16),
            if (blocked) _buildBlockedNotice(preview) else _buildCodeForm(),
            const SizedBox(height: 14),
            const Text(
              'Tautan ini tidak memberi akses tanpa kode akses yang valid. '
              'Scanner hanya terbuka untuk event pada undangan ini.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('staff-access-code-field'),
          controller: _codeController,
          enabled: !_submitting,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 18,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            LengthLimitingTextInputFormatter(9),
          ],
          decoration: const InputDecoration(
            labelText: 'Kode akses',
            hintText: 'ABCD-EFGH',
            helperText: '8 karakter, tanda hubung opsional',
            prefixIcon: Icon(Icons.key_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final code = _normalizeCode(value ?? '');
            if (code.length != 8) {
              return 'Kode akses terdiri dari 8 karakter.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
        if (_accessError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _accessError!,
              key: const Key('staff-access-error'),
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('staff-access-submit'),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.qr_code_scanner, size: 18),
          label: Text(_submitting ? 'Memverifikasi...' : 'Masuk ke Scanner'),
        ),
      ],
    ),
  );

  Widget _buildBlockedNotice(StaffInvitationPreview preview) {
    final message = preview.isRevoked
        ? 'Undangan ini sudah dicabut oleh Organizer.'
        : preview.isExpired
        ? 'Undangan ini sudah kedaluwarsa.'
        : 'Undangan ini belum memiliki kode akses.';
    return Container(
      key: const Key('staff-access-blocked'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.softRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Hubungi Organizer event untuk memperbarui undangan Anda.',
            style: TextStyle(fontSize: 11.5, color: Colors.black87),
          ),
        ],
      ),
    );
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
}

/// Kartu penolakan (tautan salah/undangan tidak ditemukan).
class _DeniedCard extends StatelessWidget {
  const _DeniedCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.gpp_bad_outlined, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}
