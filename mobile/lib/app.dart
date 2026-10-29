import 'package:flutter/material.dart';
// TODO: uncomment after adding `provider` to pubspec.yaml (PRD section 8.1)
// import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

// TODO: import providers once `provider` package is added to pubspec.yaml
// import 'providers/auth_provider.dart';
// import 'providers/event_provider.dart';

/// Root widget of the E-Ticket Event QR Scanner application.
///
/// Keeps main.dart as a thin entry point. Routing, theme, and provider setup
/// live here. Endpoint contracts are marked with TODO because the backend API
/// contract is still a draft (PRD section 15).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.initial,
      onGenerateRoute: AppRouter.generateRoute,
      // TODO: wrap with MultiProvider and register providers once `provider`
      // package is added to pubspec.yaml.
      // home: const AuthWrapper(),
    );
  }
}
