/// Komponen state UI bersama untuk layar Event Organizer.
///
/// Menyediakan loading, empty (dengan langkah berikutnya), error + retry, dan
/// akses ditolak tanpa membocorkan data event.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class OrganizerLoadingView extends StatelessWidget {
  const OrganizerLoadingView({super.key, this.message = 'Memuat data event...'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

/// Empty state dengan aksi lanjutan yang jelas.
class OrganizerEmptyView extends StatelessWidget {
  const OrganizerEmptyView({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.event_busy,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (primaryLabel != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
              ],
              if (secondaryLabel != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      );
}

/// Error state aman: pesan + tombol coba lagi.
class OrganizerErrorView extends StatelessWidget {
  const OrganizerErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Gagal memuat data',
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Akses ditolak tanpa detail event (tidak membocorkan judul/lokasi).
class OrganizerAccessDeniedView extends StatelessWidget {
  const OrganizerAccessDeniedView({
    super.key,
    this.onBack,
    this.message =
        'Event ini bukan milik akun Anda atau aksesnya sudah dicabut.',
  });

  final VoidCallback? onBack;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Akses ditolak',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              if (onBack != null) ...<Widget>[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali ke Event Saya'),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Banner informasi netral (mis. penanda data simulasi).
class OrganizerInfoBanner extends StatelessWidget {
  const OrganizerInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = AppTheme.primaryColor,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

