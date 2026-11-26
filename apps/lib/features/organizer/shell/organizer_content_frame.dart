/// Pembatas lebar konten halaman Organizer.
///
/// Pada Web/desktop kartu dan teks tidak direntangkan hingga seluruh lebar
/// layar, sehingga hierarki informasi tetap nyaman dibaca. Di mobile (layar
/// sempit) pembatas ini tidak berpengaruh karena lebar tersedia lebih kecil
/// dari [maxWidth].
library;

import 'package:flutter/material.dart';

class OrganizerContentFrame extends StatelessWidget {
  const OrganizerContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 840,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
