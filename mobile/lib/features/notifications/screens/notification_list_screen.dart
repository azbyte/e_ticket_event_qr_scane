/// Notification list screen (PRD section: Notifications).
///
/// Stub fondasi. Daftar notifikasi dan penandaan sebagai dibaca akan
/// diimplementasi setelah NotificationProvider dan endpoint notifikasi tersedia.
import 'package:flutter/material.dart';

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar notifikasi akan ditampilkan di sini.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — integrasi API dan Provider belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
