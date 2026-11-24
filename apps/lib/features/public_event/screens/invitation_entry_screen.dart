import 'package:flutter/material.dart';

import '../../staff/screens/accept_invitation_screen.dart';

/// Halaman penerimaan undangan panitia (`/invite/:token`) — route milik D1-1.
///
/// Sejak D2-2 halaman ini mendelegasikan ke [AcceptInvitationScreen] yang
/// memakai API nyata (`GET /api/invitations/:token` lalu
/// `POST /api/invitations/:token/accept`). Route tetap sama sehingga gerbang
/// login + redirect yang dibangun D1 tidak berubah.
class InvitationEntryScreen extends StatelessWidget {
  const InvitationEntryScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return AcceptInvitationScreen(token: token);
  }
}

