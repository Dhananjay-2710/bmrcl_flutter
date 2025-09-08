import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Veriphy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA7D222),
          primary: const Color(0xFFA7D222),
        ),
        useMaterial3: true,
      ),
      // No initialRoute / routes; use an AuthGate instead
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // only rebuild when token changes
    final token = context.select<AuthProvider, String?>((p) => p.token);

    if (token == null) {
      return const LoginScreen();
    }
    return const DashboardScreen();
  }
}
