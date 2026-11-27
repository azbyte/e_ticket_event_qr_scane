import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_edit_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/admin/screens/account_management_screen.dart';
import 'features/admin/screens/admin_profile_screen.dart';
import 'features/admin/screens/admin_settings_screen.dart';
import 'features/admin/screens/audit_log_screen.dart';
import 'features/admin/screens/event_moderation_screen.dart';
import 'features/admin/screens/package_management_screen.dart';
import 'features/admin/screens/report_management_screen.dart';
import 'features/admin/screens/subscription_management_screen.dart';
import 'features/admin/screens/transaction_revenue_screen.dart';
import 'features/admin/tabs/admin_tab_controller.dart';
import 'features/events/screens/event_detail_screen.dart';
import 'features/events/screens/event_list_screen.dart';
import 'features/payments/screens/payment_screen.dart';
import 'features/public_event/screens/invitation_entry_screen.dart';
import 'features/public_event/screens/public_event_screen.dart';
import 'features/public_event/screens/public_registration_screen.dart';
import 'features/organizer/membership/team_management_screen.dart';
import 'features/organizer/plans/subscription_screen.dart';
import 'features/organizer/events/screens/organizer_event_detail_screen.dart';
import 'features/organizer/screens/attendee_list_screen.dart';
import 'features/organizer/screens/event_form_screen.dart';
import 'features/organizer/screens/event_management_screen.dart';
import 'features/organizer/screens/organizer_profile_screen.dart';
import 'features/organizer/screens/organizer_order_list_screen.dart';
import 'features/organizer/screens/staff_management_screen.dart';
import 'features/organizer/operations/organizer_scan_screen.dart';
import 'features/organizer/operations/organizer_scanner_screen.dart';
import 'features/check_in/screens/check_in_history_screen.dart';
import 'features/scanner/screens/scanner_screen.dart';
import 'features/organizer/shell/access_denied_screen.dart';
import 'features/organizer/support/organizer_support_screen.dart';
import 'services/organizer_operations/organizer_permission.dart';
import 'features/staff/screens/staff_dashboard_screen.dart';
import 'features/tickets/screens/ticket_detail_screen.dart';
import 'features/tickets/screens/ticket_list_screen.dart';
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final normalized = _normalizeRouteName(settings.name);
    final uri = Uri.tryParse(normalized);
    final path = uri?.path ?? '/';
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final args = settings.arguments is Map
        ? settings.arguments as Map
        : const {};
    Widget page;

    switch (path) {
      case AppRoutes.initial:
        page = const AuthGate();
        break;
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.register:
        page = const RegisterScreen();
        break;
      case AppRoutes.profileEdit:
        page = const ProfileEditScreen();
        break;
      case AppRoutes.home:
      case AppRoutes.organizerDashboard:
        page = const RoleGuard(admin: false);
        break;
      case AppRoutes.organizerScan:
        page = const OrganizerScanScreen();
        break;
      case AppRoutes.organizerProfile:
        page = const OrganizerProfileScreen();
        break;
      case AppRoutes.organizerEvents:
        page = const EventManagementScreen();
        break;
      case AppRoutes.organizerEventCreate:
        page = const EventFormScreen();
        break;
      case AppRoutes.organizerTeam:
        page = TeamManagementScreen(
          eventId: args['eventId']?.toString() ?? '',
          eventTitle: args['eventTitle']?.toString() ?? 'Event',
        );
        break;
      case AppRoutes.organizerPlans:
        page = const SubscriptionScreen();
        break;
      case AppRoutes.organizerPlanTransactions:
        page = const SubscriptionScreen(initialTab: 1);
        break;
      case AppRoutes.organizerSupport:
        page = const OrganizerSupportScreen();
        break;
      case AppRoutes.organizerSupportNew:
        page = const OrganizerSupportScreen(initialTab: 2);
        break;
      case AppRoutes.accessDenied:
        page = AccessDeniedScreen(
          reason: args['reason']?.toString(),
          returnRoute: args['returnRoute']?.toString() ?? AppRoutes.home,
        );
        break;
      case AppRoutes.organizerEventScanner:
        page = OrganizerScannerScreen(
          eventId: args['eventId']?.toString() ?? '',
          eventName: args['eventName']?.toString() ?? 'Event',
          contextScope: OrganizerMembershipContext.owner(
            eventId: args['eventId']?.toString() ?? '',
            userId: _authUserId ?? '',
            userName: _authUserName ?? 'Penyelenggara',
          ),
        );
        break;
      case AppRoutes.staffDashboard:
        page = const StaffDashboardScreen();
        break;
      case AppRoutes.staffAssignedEvents:
        page = const StaffDashboardScreen();
        break;
      case AppRoutes.staffScanner:
        // Scanner staf memerlukan event yang benar (K3 T3-D1-02). Bila eventId
        // tidak tersedia, ScannerScreen menampilkan state "belum ada event"
        // yang jujur; dashboard staf adalah tempat memilih event.
        page = args['eventId'] == null
            ? const StaffDashboardScreen()
            : ScannerScreen(
                eventId: args['eventId']?.toString() ?? '',
                staffId: args['staffId']?.toString() ?? _authUserId ?? '',
                staffName: args['staffName']?.toString() ?? _authUserName ?? '',
              );
        break;
      case AppRoutes.checkInHistory:
        page = args['eventId'] == null
            ? const StaffDashboardScreen()
            : CheckInHistoryScreen(
                eventId: args['eventId']?.toString() ?? '',
              );
        break;
      case AppRoutes.adminDashboard:
        page = const AdminTabController();
        break;
      case AppRoutes.adminEventModeration:
        page = const EventModerationScreen();
        break;
      case AppRoutes.adminAccounts:
        page = const AccountManagementScreen();
        break;
      case AppRoutes.adminReports:
        page = const ReportManagementScreen();
        break;
      case AppRoutes.adminPackages:
        page = const PackageManagementScreen();
        break;
      case AppRoutes.adminSubscriptions:
        page = const SubscriptionManagementScreen();
        break;
      case AppRoutes.adminTransactions:
        page = const TransactionRevenueScreen();
        break;
      case AppRoutes.adminSettings:
        page = const AdminSettingsScreen();
        break;
      case AppRoutes.adminAuditLog:
        page = const AuditLogScreen();
        break;
      case AppRoutes.adminProfile:
        page = const AdminProfileScreen();
        break;
      case AppRoutes.eventList:
        page = const EventListScreen();
        break;
      case AppRoutes.ticketList:
        page = const TicketListScreen();
        break;
      default:
        if (parts.length == 2 && parts[0] == 'events') {
          page = EventDetailScreen(eventId: parts[1]);
        } else if (parts.length == 2 && parts[0] == 'tickets') {
          page = TicketDetailScreen(ticketId: parts[1]);
        } else if (parts.length == 2 && parts[0] == 'e') {
          // Tautan pendaftaran publik: dapat dibuka guest tanpa login (D1-1).
          page = PublicEventScreen(eventId: parts[1]);
        } else if (parts.length == 3 &&
            parts[0] == 'e' &&
            parts[2] == 'register') {
          page = PublicRegistrationScreen(eventId: parts[1]);
        } else if (parts.length == 4 &&
            parts[0] == 'e' &&
            (parts[2] == 'order' || parts[2] == 'payment')) {
          page = PaymentScreen(orderId: parts[3]);
        } else if (parts.length == 4 &&
            parts[0] == 'e' &&
            parts[2] == 'ticket') {
          page = TicketDetailScreen(ticketId: parts[3]);
        } else if (parts.length == 2 && parts[0] == 'invite') {
          page = InvitationEntryScreen(token: parts[1]);
        } else if (parts.length == 2 && parts[0] == 'registration') {
          // Alur pendaftaran guest melalui tautan pendaftaran (PRD §7).
          // Wajib memakai layar guest: peserta tidak perlu login, dan formulir
          // mengikuti konfigurasi field milik event tersebut.
          page = PublicRegistrationScreen(eventId: parts[1]);
        } else if (parts.length == 2 && parts[0] == 'staff') {
          page = StaffDashboardScreen(eventId: parts[1]);
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'edit') {
          page = EventFormScreen(eventId: parts[2]);
        } else if (parts.length == 3 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events') {
          page = OrganizerEventDetailScreen(eventId: parts[2]);
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'staff') {
          page = StaffManagementScreen(
            eventId: parts[2],
            eventName: args['eventName']?.toString() ?? 'Event',
          );
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'attendees') {
          page = AttendeeListScreen(eventId: parts[2]);
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'orders') {
          page = OrganizerOrderListScreen(
            eventId: parts[2],
            eventName: args['eventName']?.toString() ?? 'Event',
            contextScope:
                _organizerContextFor(parts[2], args) ?? _ownerFallback(parts[2]),
          );
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'scanner') {
          page = OrganizerScannerScreen(
            eventId: parts[2],
            eventName: args['eventName']?.toString() ?? 'Event',
            contextScope:
                _organizerContextFor(parts[2], args) ?? _ownerFallback(parts[2]),
          );
        } else if (parts.length >= 2 && parts.first == 'admin') {
          page = const RoleGuard(admin: true);
        } else if (parts.length >= 2 && parts.first == 'organizer') {
          page = const RoleGuard(admin: false);
        } else {
          page = const Scaffold(
            body: Center(child: Text('Halaman tidak ditemukan')),
          );
        }
    }

    Widget guardedBuilder(BuildContext context) {
      final auth = context.read<AuthProvider>();
      final role = auth.user?.role.name;
      // Identitas owner untuk layar yang butuh konteks membership Organizer.
      _authUserId = auth.user?.id;
      _authUserName = auth.user?.name;
      final adminRoute =
          path == AppRoutes.adminDashboard || path.startsWith('/admin/');
      final organizerRoute =
          path == AppRoutes.organizerDashboard ||
          path.startsWith('/organizer/');

      // Public / non-auth routes (D1-1)
      if (_isPublicPath(path)) {
        if ((path == AppRoutes.login || path == AppRoutes.register) &&
            auth.isAuthenticated) {
          return role == 'admin'
              ? const RoleGuard(admin: true)
              : const RoleGuard(admin: false);
        }
        // Undangan panitia memerlukan login; setelah login pengguna kembali
        // ke halaman penerimaan undangan (K3).
        if (_isInvitationPath(path) && !auth.isAuthenticated) {
          return LoginScreen(redirectRoute: path);
        }
        return page;
      }

      // Must be authenticated for other routes
      if (!auth.isAuthenticated) {
        return const LoginScreen();
      }

      // Admin route guard
      if (adminRoute && role != 'admin') {
        return AccessDeniedScreen(
          reason: 'Halaman ini khusus untuk Administrator Platform.',
          returnRoute: _homeRouteForRole(role),
        );
      }

      // Organizer route guard
      if (organizerRoute && role != 'organizer') {
        return AccessDeniedScreen(
          reason: 'Halaman ini khusus untuk Penyelenggara Acara (Organizer).',
          returnRoute: _homeRouteForRole(role),
        );
      }

      return page;
    }

    if (page is EventFormScreen) {
      return MaterialPageRoute<bool>(
        settings: settings,
        builder: guardedBuilder,
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: guardedBuilder,
    );
  }

  /// Konteks membership untuk layar Organizer yang membutuhkan permission.
  ///
  /// Identitas owner dibaca dari [AuthProvider] oleh [generateRoute] dan
  /// diteruskan lewat field privat di bawah; argumen route dapat menimpanya
  /// bila pemanggil sudah memiliki data membership nyata. Tidak ada lagi ID
  /// owner hardcoded.
  static String? _authUserId;
  static String? _authUserName;

  static OrganizerMembershipContext? _organizerContextFor(
    String eventId,
    Map args,
  ) {
    final explicit = args['contextScope'];
    if (explicit is OrganizerMembershipContext) return explicit;

    final userId = args['userId']?.toString() ?? _authUserId;
    if (userId == null || userId.isEmpty) return null;
    return OrganizerMembershipContext.owner(
      eventId: eventId,
      userId: userId,
      userName: args['userName']?.toString() ?? _authUserName ?? 'Penyelenggara',
    );
  }

  /// Konteks owner berdasarkan identitas sesi aktif.
  ///
  /// Permission di layar yang memakai konteks ini tetap divalidasi ulang oleh
  /// backend (`POST /api/tickets/validate` & `/api/check-ins`), sehingga
  /// konteks ini hanya menentukan tampilan, bukan otorisasi data.
  static OrganizerMembershipContext _ownerFallback(String eventId) =>
      OrganizerMembershipContext.owner(
        eventId: eventId,
        userId: _authUserId ?? '',
        userName: _authUserName ?? 'Penyelenggara',
      );

  static String _homeRouteForRole(String? role) => switch (role) {
    'admin' => AppRoutes.adminDashboard,
    'organizer' => AppRoutes.organizerDashboard,
    'staff' => AppRoutes.staffDashboard,
    _ => AppRoutes.eventList,
  };

  /// Route yang boleh diakses tanpa token (PRD §6.1, §7).
  ///
  /// `/e/**` adalah landing + registrasi + pembayaran + tiket guest, dan
  /// `/registration/:eventId` adalah tujuan tautan pendaftaran. Keduanya publik;
  /// seluruh route lain (dashboard Organizer/Admin, data peserta, scanner) tetap
  /// memerlukan login dan otorisasi backend.
  static bool _isPublicPath(String path) {
    if (path == AppRoutes.initial ||
        path == AppRoutes.login ||
        path == AppRoutes.register ||
        path == AppRoutes.accessDenied) {
      return true;
    }
    if (path == '/e' || path == '/registration') return true;
    return path.startsWith('/e/') ||
        path.startsWith('/invite/') ||
        path.startsWith('/registration/');
  }

  /// Normalisasi nama route dari platform/browser.
  ///
  /// Mendukung tiga bentuk tautan yang mungkin dibuka peserta:
  /// 1. path strategy baru: `/e/{eventId}`,
  /// 2. hash strategy lama: `/#/e/{eventId}` (fragment berisi `/e/{eventId}`),
  /// 3. URL absolut hasil salin dari address bar:
  ///    `http://host:3100/e/{eventId}?x=1`.
  ///
  /// Tanpa normalisasi, bentuk (2) dan (3) akan dianggap route `/` sehingga
  /// pengguna diarahkan ke halaman login.
  static String _normalizeRouteName(String? raw) {
    final name = (raw == null || raw.trim().isEmpty) ? '/' : raw.trim();
    final uri = Uri.tryParse(name);
    if (uri == null) return name;

    if (uri.hasScheme && uri.host.isNotEmpty) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }
    if ((uri.path.isEmpty || uri.path == '/') &&
        uri.fragment.startsWith('/')) {
      return uri.fragment;
    }
    return name;
  }

  static bool _isInvitationPath(String path) => path.startsWith('/invite/');
}
