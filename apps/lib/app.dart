import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/admin/tabs/admin_tab_controller.dart';
import 'features/events/screens/event_list_screen.dart';
import 'features/organizer/screens/organizer_dashboard_screen.dart';
import 'features/staff/screens/staff_dashboard_screen.dart';
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';
import 'app_router.dart';
import 'services/auth/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AuthProvider(AuthService())..restoreSession(),
        child: MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.initial,
          routes: {
            AppRoutes.initial: (_) => const AuthGate(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.adminDashboard: (_) => const RoleGuard(admin: true),
            AppRoutes.organizerDashboard: (_) => const RoleGuard(admin: false),
          },
          onGenerateRoute: AppRouter.generateRoute,
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) return const _LoadingScreen();
          if (!auth.isAuthenticated) return const LoginScreen();
          return _homeForRole(auth.user!.role.name);
        },
      );
}

class RoleGuard extends StatelessWidget {
  const RoleGuard({super.key, required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) return const _LoadingScreen();
          if (!auth.isAuthenticated) return const LoginScreen();
          final role = auth.user!.role.name;
          if (role != (admin ? 'admin' : 'organizer')) {
            return _homeForRole(role);
          }
          return admin
              ? const AdminTabController()
              : const OrganizerDashboardScreen();
        },
      );
}

Widget _homeForRole(String role) => role == 'admin'
    ? const RoleGuard(admin: true)
    : role == 'organizer'
        ? const RoleGuard(admin: false)
        : role == 'staff'
            ? const StaffDashboardScreen()
            : role == 'attendee'
                ? const EventListScreen()
                : const LoginScreen();

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}